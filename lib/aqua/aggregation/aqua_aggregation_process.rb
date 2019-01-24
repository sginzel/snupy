class AquaAggregationProcess
	include ActionView::Helpers::TextHelper
	
	def initialize(experimentid = nil, varcallids = nil, binding = nil)
		@experimentid = experimentid
		varcallids = [] if varcallids.nil?
		@varcallids = varcallids.uniq.sort
		@binding = binding
		@colors = {}
		@sample_ids = nil
		@organism = nil
	end
	
	def flash(type, message)
		if !@binding.nil? then
			eval("flash[:#{type}] = \"\" if flash[:#{type}].nil?; flash[:#{type}] << '#{message}; '", @binding)
		end
	end
	
	## uses db streaming if possible.
	def start_batch(params, use_stream = true)
		aqparams = Aqua.parse_params(params)
		if (!aqparams["aggregations"].nil? & !aqparams[:aggregations].nil?)
			Aggregation.log_warn "different aggregation values given. \n#{caller[0..3].join("\n")}\n"
		end
		aggregations = (aqparams[:aggregations] || aqparams["aggregations"])
		group_aggregations = (aggregations["group"] || aggregations[:group] || [])
		group_aggregation = group_aggregations.first
		attr_aggregations = (aggregations["attribute"] || aggregations[:attribute] || [])
		attr_aggregations += (aggregations["batch"] || aggregations[:batch] || [])
		
		sample_ids = (params[:samples] || params["samples"])
		sample_ids = [sample_ids] unless sample_ids.is_a?(Array)
		if (!@experimentid.nil?)
			experiment = Experiment.find(@experimentid)
			sample_ids = experiment.sample_ids if sample_ids.nil?
			organism = experiment.organism
		else
			organisms = Organism.joins(:samples).where('samples.id' => sample_ids).uniq.reload
			organism = organisms.first
			# for some reason we have to use .map here, because otherwise the number of
			# orgnaisms is not determined correctly
			raise "Not all samples(#{sample_ids[0..10].join(",")}) belong to the same organism" if organisms.map(&:name).size > 1
		end
		@organism = organism
		@sample_ids = sample_ids
		organismid = organism.id
		# query each aggregation by its own
		aggregation_scopes = {}
		scope = VariationCall
							.where(sample_id: sample_ids)
							.select("variation_calls.id AS `variation_calls.id`")
		scope = scope.where("variation_calls.id" => @varcallids) unless @varcallids.nil?
		attr_aggregations.each do |a|
			scope = a.add_required(scope, organismid)
		end
		# we can use streaming to prevent MySQL from creating a temporary table. This should increase speed - but it does with the test data. Could be the overhead of allocating memory for result
		if Rails.env == "development" or use_stream then
			result = []
			Aqua.scope_to_array(scope){|r|
				result << r
			}
		else
			result = Aqua.scope_to_array(scope)
		end
		return result.uniq
	end
	
	def start(params, allow_tags = true)
#x=SnupyAgain::Profiler.profile("aggregation") {
		params = params.dup
		result = EventLog.record do |eventlog|
			begin
				aqparams = Aqua.parse_params(params)
				if (!aqparams["aggregations"].nil? & !aqparams[:aggregations].nil?)
					Aggregation.log_warn "different aggregation values given. \n#{caller[0..3].join("\n")}\n"
				end
				aggregations = (aqparams[:aggregations] || aqparams["aggregations"])
				group_aggregations = (aggregations["group"] || aggregations[:group] || [])
				group_aggregation = group_aggregations.first
				attr_aggregations = (aggregations["attribute"] || aggregations[:attribute] || [])
				experiment = Experiment.find(@experimentid)
				sample_ids = (params[:samples] || params["samples"])
				sample_ids = [sample_ids] unless sample_ids.is_a?(Array)
				organismid = experiment.organism.id
				
				# set some nice values in params to be used inside aggregations
				params[:organismid] = organismid
				params[:organism_id] = organismid
				params[:experiment_id] = @experimentid
				params[:experimentid] = @experimentid
				
				
				# scope = Aqua.base_scope(@experimentid, sample_ids, true, true, true, true)
				# query each aggregation by its own
				aggregation_scopes = {}
				# aggregation_scopes[Aggregation] = Aqua.base_scope(@experimentid, sample_ids, true, true, true, true)
				aggregation_scopes[Aggregation] = Aqua.base_scope(@experimentid, sample_ids, false, false, false, false)
				aggregation_scopes[Aggregation] = group_aggregation.add_required(aggregation_scopes[Aggregation], organismid) unless group_aggregation.nil?
				akeys = []
				attr_aggregations.each do |a|
					#aggrs.each do |a|
						## prepare scope
						if aggregation_scopes[a.class].nil? then
							# scope = Aqua.base_scope(@experimentid, sample_ids, false, false, false, false)
							scope = VariationCall.where(sample_id: sample_ids).select("variation_calls.id AS `variation_calls.id`")
							scope = group_aggregation.add_required(scope, organismid) unless group_aggregation.nil?
						else
							scope = aggregation_scopes[a.class]
						end
						akeys << a.akey
						aggregation_scopes[a.class] = a.add_required(scope, organismid)
					#end
				end
				
				#aggregations.each do |type, aggrs|
				#	aggrs.each do |a|
				#		scope = a.add_required(scope, organismid)
				#	end
				#end
				
				# Get data from server
				scoperesults = {}
				astart = Time.now
				aggregation_scopes.each do |agg, scope|
					scoperesults[agg] = [] if scoperesults[agg].nil?
					cnt = 0
					@varcallids.each_slice(1000) do |batch|
						cnt += 1
						if Rails.env == "development"
							fout = File.new("tmp/last_#{agg.name}_sql_#{cnt}.sql", "w+")
							fout.write(scope.where("variation_calls.id" => batch).to_sql)
							fout.close()
						end
						scoperesults[agg] += Aqua.scope_to_array(scope.where("variation_calls.id" => batch))
					end
				end
				d "retrieved results for #{@varcallids.size} (before grouping)....#{scoperesults.map{|tool, res| "#{tool.name}:#{res.size}"}.join(", ")}"
				aretrievend = Time.now
				
				# Perform grouping operations -> group by attributes
				## by default we use the variation_call id which results in one record per row...
				# if there is a group_aggregation method we use this...
				scoperesults.keys.each do |agg|
					if !group_aggregation.nil? then
						group_aggregation.execute_hook(scoperesults[agg], group_aggregation.configuration, :prehook, params) unless group_aggregation.configuration[:prehook].nil?
					end
				end
				scoperesults.keys.each do |agg|
					grouped_scope_result = {}
					# call prehook if it exists
					scoperesults[agg].each do |rec|
						record_key = rec["variation_calls.id"]
						record_key = group_aggregation.aggregate_group(rec) unless group_aggregation.nil?
						grouped_scope_result[record_key] = [] if grouped_scope_result[record_key].nil?
						grouped_scope_result[record_key] << rec
					end
					scoperesults.delete(agg)
					scoperesults[agg] = grouped_scope_result
				end
				scoperesults.keys.each do |agg|
					if !group_aggregation.nil? then
						group_aggregation.execute_hook(scoperesults[agg], group_aggregation.configuration, :posthook, params) unless group_aggregation.configuration[:posthook].nil?
					end
				end
				agroupend = Time.now
				
				## Now parse the SQL results to aggregate records to meaningful
				## results
				d "retrieved results (after grouping)....#{scoperesults.map{|tool, res| "#{tool.name}:#{res.size}"}.join(", ")}"
				attr_aggregations.each do |ainst|
					ainst.aggregate(scoperesults[ainst.class], params)
				end
				aagregateend = Time.now
				## now let's construct the array of colnames the user wants to see.
				## for this we iterate over the selected attribute aggregations and sort the column names
				colnames = %w(variation_calls.id)# variation_calls.variation_id)
				colnames += attr_aggregations.sort{|a1, a2|
					a1cidx = a1.config()[:colindex].to_f
					a2cidx = a2.config()[:colindex].to_f
					if a1cidx == a2cidx then
						a1.config()[:colname] <=> a2.config()[:colname]
					else
						a1cidx <=> a2cidx
					end
				}.map{|a| a.colnames}.flatten.uniq
				
				## now lets go over all the uniq group ids that are available
				## The ID of the records is set here
				rownames = scoperesults.map{|agg, group_id_to_records| group_id_to_records.keys}.flatten.uniq
				tbl = Hash[rownames.map{|rn| [rn, {id: [rn]}]}]
				#tbl = Hash[rownames.map{|rn|
				#	if !rn.is_a?(Hash) then
				#		[rn, {id: [rn]}]
				#	else
				#		[rn, {id: [rn[:id]].flatten, model: [rn[:model]]}]
				#	end
				#}]
				scoperesults.each do |agg, rowname_to_records|
					rowname_to_records.each do |rowname, records|
						records.each do |rec|
							colnames.each do |colname|
								tbl[rowname][colname] = [] if tbl[rowname][colname].nil?
								if !rec[colname].nil? then
									if allow_tags then
										tbl[rowname][colname] << rec[colname]
									else
										# strip tags on string
										if rec[colname].is_a?(String) then
											tbl[rowname][colname] << strip_tags(rec[colname])
										else
											tbl[rowname][colname] << rec[colname]
										end
									end
								end
							end
						end
					end
				end
				aagregateend1 = Time.now
				
				tbl.each do |rowname, rec|
					rec.keys.each do |colname|
						rec[colname] = rec[colname].uniq.join(" | ")
					end
				end
				aagregateend2 = Time.now
				
				duration_data_retrieval = (aretrievend - astart).to_f.round(2)
				duration_rest = (Time.now - aretrievend).to_f.round(2)
				
				ret = tbl.values.flatten
				log_entry = {
					akeys: akeys,
					num_akeys: akeys.size,
					num_columns: (ret.first || {}).keys.length,
					duration_retrieval: (aretrievend - astart).to_f,
					duration_preparation: (Time.now - aretrievend).to_f,
					experiment: @experimentid,
					samples: sample_ids,
					num_samples: sample_ids.size,
					aqua_aggregation_process_id: params.hash.abs.to_s(36).upcase
				}
				log_entry[:duration] = log_entry[:duration_retrieval] + log_entry[:duration_preparation]
				eventlog.data = log_entry
				eventlog.identifier = params.hash.abs.to_s(36).upcase
				
				flash(:notice, "Data retrieved in #{duration_data_retrieval} sec. prepared in #{duration_rest} sec to #{ret.size} grouped records.")
			rescue RuntimeError => e
				eid = "#{e.hash.to_i.abs.to_s(16)}|#{Time.now}"
				Aggregation.log_error "[##{eid}] ERROR in Aggregation process"
				Aggregation.log_error "[##{eid}] " + e.message
				Aggregation.log_error "[##{eid}] " + e.backtrace.join("\n[##{eid}] ")
				Aggregation.log_error "[##{eid}] END of ERROR ##{eid}"
				Aggregation.log_error "[##{eid}] PARAMS \n[##{eid}] #{params.pretty_inspect.split("\n").join("\n[##{eid}] ")}"
				Aggregation.log_error "Aggregation Process Failed. Please contact the admin (ErrorRefID ##{eid.split("|")[0]})"
				collection = []
				flash(:alert, "Aggregation Process Failed. Please contact the admin (ErrorRefID ##{eid.split("|")[0]})")
				ret = []
				raise "[##{eid}] " + e.message if @binding.nil? # in that case we have no way to communicate an error back to the user
			end
			ret
		end
		result

	end
	
	def sample_ids
		@sample_ids
	end
	
	def organism
		@organism
	end
	
	def varcallids
		@varcallids
	end
end