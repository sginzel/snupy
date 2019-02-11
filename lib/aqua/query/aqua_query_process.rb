# == Description
# The AquaQueryProcess implements the process to query an experiment using a defined set of filters 
# == Example
#      # Setup Process for VcfFile
#      qp = AquaQueryProcess.new(Experiment.first.id)
#      # params as defined by the HTTP request
#      params = { queries: {
#                    query_gene_id: {
#                      filters: {
#                        vep_gene_id: [:hgnc, :ensembl_gene_id, :ncbi_gene_id]
#                      },
#                      combine: "AND"/"OR",
#                      value: "SOME USER STRING - OR - Array - OR - 1/0" 
#                    }
#                  }
#                }
#      # start the process
#      varcallids = qp.start(params)
#      puts "#{varcallids.size} variation calls found"
#  
class AquaQueryProcess 
	@experimentid = nil
	
	def self.test()
		experimentid = 23
		sample_ids = [148]
		ap = AquaQueryProcess.new(23)
		params = Aqua._example_params()
		queries = Aqua.parse_params(params)[:queries]
		queries = queries.first[1].values.flatten
		scope = ap.prepare_scope(queries, nil, [148], 1)
		queries.each do |q|
			scope = q.query(scope)
		end
		return(scope) if 1 == 1
		arr = Aqua.scope_to_array(scope)
	end
	
	def initialize(experimentid = nil, binding = nil)
		@experimentid = experimentid
		@experimentid = experimentid.id if experimentid.is_a?(Experiment)
		@binding = binding
		@sample_ids = nil
		@organism = nil
		@sql_statements = []
		@identifier = "QP#{Time.now.to_i.to_s(36).upcase}"
	end
	
	def flash(type, message)
		if !@binding.nil? then
			#eval("flash.#{type} = '#{message}'", @binding)
			eval("flash[:#{type}] = \"\" if flash[:#{type}].nil?; flash[:#{type}] << '#{message}; '", @binding)
		end
	end
	
	def start(params, unlimited = false)
		## Example
		# @experimentid = 23
		# @sample_ids = [148]
		# params = Aqua._example_params()
		# queries = Aqua.parse_params(params)[:queries]
		# queries = queries.first[1].values.flatten
		# scope = AquaQueryProcess.prepare_scope(queries, [148], 1)
		# arr = AquaQueryProcess.new_scope_to_array(scope)
		# d "[#{Time.now}] - Starting Query Process FROM"
		# d caller[0..3].join("\n")
		result = EventLog.record do |eventlog|
			begin
				# Removed requirements for user - not sure why this was there in the first place
				# params[:user] = params["user"] if params[:user].nil?
				params[:samples] = params["samples"] if params[:samples].nil?
				params[:experiment] = params["experiment"] if params[:experiment].nil?
				
				# raise "No user was submited to query process (#{params.pretty_inspect})" if params[:user].nil?
				raise "No samples submitted to query process (#{params.pretty_inspect})" if params[:samples].nil?
				#raise "No experiment submitted to query process (#{params.pretty_inspect})" if params[:experiment].nil?
				
				qparams = Aqua.parse_params(params)
				if (!qparams["queries"].nil? & !qparams[:queries].nil?)
					Query.log_warn "different query values given \"queries\" and :queries. \n#{caller[0..3].join("\n")}\n"
				end
				
				queries = qparams[:queries]
				Query.log_warning("No Queries given.") if queries.size == 0
				flash(:alert, "Select at least one Query") if queries.size == 0
				return [] if queries.size == 0 # no queries - no result
		
				sample_ids = (params[:samples] || params["samples"])
				if !@experimentid.nil? then
					experiment = Experiment.find(@experimentid)
					organism = experiment.organism
				else
					# else we need to determine the organism from the samples
					organisms = Organism.joins(:samples).where('samples.id' => sample_ids).uniq.reload
					organism = organisms.first
					# for some reason we have to use .map here, because otherwise the number of
					# orgnaisms is not determined correctly
					raise "Not all samples(#{sample_ids[0..10].join(",")}) belong to the same organism" if organisms.map(&:name).size > 1
				end
				@organism = organism
				
				# set some nice values in params to be used inside aggregations
				params[:organismid] = organism.id
				params[:organism_id] = organism.id
				params[:experiment_id] = experiment.id
				params[:experimentid] = experiment.id
				
				sample_ids = [sample_ids] unless sample_ids.is_a?(Array)
				if sample_ids.nil? || sample_ids.size == 0 then
					puts "[WARNING] No samples selected for query process"
					Query.log_error "[WARNING] No samples selected for query process"
					return nil
				end
	
				sample_ids.flatten!
				@sample_ids = sample_ids
				simple_queries = queries.select{|klass, klassqueries|  klass.is_simple?}
				                         .map{|klass, klassqueries| klassqueries.values}
				                         .flatten
				                         .select{|q| q.filters.size > 0}
				                         .sort{|q1, q2| q1.priority <=> q2.priority}
				complex_queries = queries.select{|klass, klassqueries| klass.is_complex?}
				                         .map{|klass, klassqueries| klassqueries.values}
				                         .flatten
				                         .select{|q| q.filters.size > 0}
				                         .sort{|q1, q2| q1.priority <=> q2.priority}
				
				qstart = Time.now
				overall_result = []
	
				max_result = (Aqua.settings["max_result"] || 1000).to_i
				# there are two batch sizes. One for big queryies that users might use in a project
				# default is 20, so they might have to wait a bit for the result
				# if the size is exceeded we assume there is a meta query being processed, which can
				# take a lot of time so we put it in smaller chunks (default 10)
				size1 = (Aqua.settings["batch_size"] || 10).to_i
				if @sample_ids.size < size1
					batch_size = size1
				else
					batch_size =  (Aqua.settings["batch_size2"] || 2).to_i # make sure large queries dont kill the server memory
				end
				# Filters such as the max_num_patient filter need to be processed on all samples at once to give a correct result
				# But only these kind of filters break this piece by piece approach
				if not (simple_queries + complex_queries).all?{|q| q.config[:use_query_splicing] } then
					batch_size = @sample_ids.size
				end
				if @experimentid.to_i < 0 # meta projects should not be queried in this way and have a max of 1.000.000 records returned by default
					batch_size = @sample_ids.size
					max_result = [max_result, 1000000].max
				end
				
				# slices = sample_ids.each_slice(batch_size)
				slices = AquaQueryProcess.get_slices(@sample_ids, batch_size)
				Aqua::Query.log_info("[STATS-#{self.queryid}] Starting query on Experiment(##{@experimentid}) with #{slices.size} batches of size #{batch_size} (#{slices.map{|s| s.size}.join(",")}) (max allowed: #{max_result})")
				Aqua::Query.log_info("[STATS-#{self.queryid}] #samples: #{@sample_ids.size}, #queries: #{simple_queries.size + complex_queries.size}, #filters: #{(simple_queries+complex_queries).map(&:filters).map(&:size).inject(&:+)}")
				Aqua::Query.log_info("[STATS-#{self.queryid}] SLICES: #{slices.join(";")}")
				slices.each_with_index do |sample_batch, i|
					sample_batch = [sample_batch] unless sample_batch.is_a?(Array)
					exp_scope = prepare_scope(simple_queries, complex_queries,
																		sample_batch, organism)
					simple_queries.each do |q|
						# TODO Use merge method to merge two scopes
						# This way multiple where conditions on the same field will be handled better
						exp_scope = q.query(exp_scope, {"samples" => sample_batch, samples: sample_batch, all_samples: @sample_ids, "all_samples" => @sample_ids})
						break if exp_scope.nil?
					end
					if exp_scope.nil?
						Aqua::Query.log_info("[#{self.queryid}] SQL Filter returned nil. ")
						# return nil if exp_scope.nil? # this can happen if a filter is not fulfilable. Such as when a compound heterozyogous model could not be found.
						next #if exp_scope.nil? # this can happen if a filter is not fulfilable. Such as when a compound heterozyogous model could not be found.
					end
					
					if (Rails.env == "development" || Aqua.settings("log_query") == "true") then
						File.open("tmp/aqua_query_#{self.queryid}_BATCH#{i}.sql", "w+"){|f| f.write exp_scope.to_sql}
					end
					# we can use streaming to prevent MySQL from creating a temporary table. This should increase speed - but it does with the test data. Could be the overhead of allocating memory for result
					# Leaving this here for reference
					if Rails.env == "development" and 1 == 0 then
						sql_results = []
						Aqua.scope_to_array(exp_scope){|r|
							sql_results << r
						}
					else
						sql_results = Aqua.scope_to_array(exp_scope)# SnupyAgain::Utils.scope_to_array(exp_scope)
					end
					@sql_statements << exp_scope.to_sql
					
					complex_queries.each do |q|
						sql_results = q.query(sql_results, {"samples": sample_batch, samples: sample_batch})
						Aqua::Query.log_info("[#{self.queryid}] Complex Filter returned nil. ") if sql_results.nil?
						break if sql_results.nil?
					end
					## reduce to variation call ids
					result = (sql_results || []).map{|rec| rec["variation_calls.id"] }.uniq
					overall_result += result
					Aqua::Query.log_info("Capacity reached (#{overall_result.size}) at #{i} slice ") if (overall_result.size >= max_result) & !unlimited
					break if (overall_result.size >= max_result) & !unlimited
				end
				result = overall_result
				qtime = Time.now - qstart
				Aqua::Query.log_info("[STATS-#{self.queryid}] Query executed in #{qtime.to_f.round(2)} seconds with #{result.size} records (max allowed: #{max_result})")
				
				if (result.size >= max_result) & !unlimited
					flash(:alert, "Query exceeded maximum number of #{max_result} records (we stopped at #{result.size}, there maybe more). Please use stricter filters.")
					Aqua::Query.log_warn("[#{self.queryid}] Query exceeded maximum number of #{max_result} records (we stopped at #{result.size}, there maybe more). Please use stricter filters.")
					# if @binding is nil we have no other way but to raise an error - this happens for example when a query is submitted as a job
					if @binding.nil?
						raise "Query exceeded maximum number of #{max_result} records (we stopped at #{result.size}, there maybe more). Please use stricter filters."
					end
					return nil
				else
					flash(:notice, "Query executed in #{qtime.to_f.round(2)} seconds with #{result.size} records (max allowed: #{max_result})")
				end
				num_vars = VariationCall.where(id: result).uniq.count(:variation_id)
				eventlog.identifier = params.hash.abs.to_s(36).upcase
				eventlog.data = {
					num_samples: @sample_ids.size,
					num_queries: simple_queries.size + complex_queries.size,
					num_filters: (simple_queries+complex_queries).map(&:filters).map(&:size).inject(&:+),
					qkeys: (simple_queries+complex_queries).map(&:qkey),
					fkeys: (simple_queries+complex_queries).map(&:filters).flatten.map(&:fkey),
					qkeyvalue: (simple_queries+complex_queries).map{|q| {q.qkey => {value: q.value, combine: q.combine} } },
					resultsize: result.size,
					num_vars: num_vars,
					aqua_query_process_id: params.hash.abs.to_s(36).upcase,
					exceeded: (result.size >= max_result) & !unlimited,
					max_result: max_result,
					time: qtime.to_f.round(4),
					experiment: @experimentid,
					samples: @sample_ids
				}
				Aqua::Query.log_info("[STATS-#{self.queryid}] STATRECORD #{{
						num_samples: @sample_ids.size,
						num_queries: simple_queries.size + complex_queries.size,
						num_filters: (simple_queries+complex_queries).map(&:filters).map(&:size).inject(&:+),
						qkeys: (simple_queries+complex_queries).map(&:qkey).join(";"),
						fkeys: (simple_queries+complex_queries).map(&:filters).flatten.map(&:fkey).join(";"),
						qkeyvalue: AquaQueryProcess.encode_for_log((simple_queries+complex_queries).map{|q| {q.qkey => {value: q.value, combine: q.combine} } }),
						resultsize: result.size,
						num_vars: num_vars,
						exceeded: (result.size >= max_result) & !unlimited,
						max_result: max_result,
						time: qtime.to_f.round(4),
						experiment: @experimentid,
						samples: @sample_ids.join(";")
				}.to_a.map{|x| x.join("=")}.join("\t")}")
			rescue RuntimeError => e
				eid = "#{e.hash.to_i.abs.to_s(16)}|#{Time.now}"
				Query.log_error "[##{eid}] ERROR in QUERY process {#{e.class}} (FROM: #{caller.first.split("/").last})\n"
				Query.log_error "[##{eid}] BEGIN ERROR ! #####################################################\n"
				Query.log_error ("[##{eid}] " + e.message + "\n")
				Query.log_error "[##{eid}] END ERROR #####################################################\n"
				Query.log_error "[##{eid}] " + e.backtrace[0..10].join("\n[##{eid}] ")
				Query.log_error "[##{eid}] PARAMS \n[##{eid}] #{params.pretty_inspect.split("\n")[0..10].join("\n[##{eid}] ")}..."
				Query.log_error "[##{eid}] END of ERROR ##{eid}"
				Query.log_error "Query Process Failed. Please contact the admin (ErrorRefID: ##{eid.split("|")[0]})"
				collection = []
				flash(:alert, "Query Process Failed. Please contact the admin (ErrorRefID: ##{eid.split("|")[0]})")
				result = []
				raise "[##{eid}] " + e.message if @binding.nil? # in that case we have no way to communicate an error back to the user
			end
			result
		end
		result
	end
	
	def sample_ids
		@sample_ids
	end
	
	def organism
		@organism
	end
	
	def sql_statements
		@sql_statements
	end
	
	def queryid
		@identifier
	end
	
	def prepare_scope(simple, complex, sample_ids, organism)
		# queries = [simple, complex].flatten.reject(&:nil?)
		# find base scope
		scope = Aqua.base_scope(@experimentid, sample_ids)
		#experiment = Experiment.find(@experimentid)
		# simple queries dont need their columns in the SELECT field
		simple.each do |q|
			scope = q.add_required(scope, false, organism.id)
		end
		# complex queries do need the required fields in the SELECT statement.
		complex.each do |q|
			scope = q.add_required(scope, true, organism.id)
		end
		return scope
	end
	
	def self.get_slices(sample_ids, batch_size)
		# the sample ids should be processed per specimen - this is relevant for the detection of digenic associations
		spec2smpl = {}
		Sample.where(id: sample_ids).select([:id, :specimen_probe_id]).each do |smpl|
			spec2smpl[smpl.specimen_probe_id] ||= []
			spec2smpl[smpl.specimen_probe_id] << smpl.id
		end
		
		# we need to handle sample where no specimen probe is set...
		if (!spec2smpl[nil].nil?) then
			spec2smpl[nil].each_slice(batch_size).to_a.each_with_index{|slice, idx|
				spec2smpl["nil_#{idx}"] = slice
			}
			spec2smpl.delete(nil)
		end
		# merge the specimen -> sample lists so we get batches of the designated size and not just process each specimen
		slices = []
		slice = []
		
		spec2smpl.each do |specid, smpls|
			slice += smpls
			if slice.size > 0.9*batch_size
				slices << slice
				slice = []
			end
		end
		slices << slice if slice.size > 0
		if (slices.flatten.size != sample_ids.size) then
			raise 'Not all samples were properlice put in slices'
		end
		slices
	end
	
	
	def self.encode_for_log(obj)
		Base64.encode64(obj.to_yaml).gsub("\n","§")
	end
	
	def self.decode_from_log(str)
		YAML.load(Base64.decode64(str.gsub("§","\n")))
	end
	
	def self.get_query_log(html_sanitize = false)
		@query_log = []
		# EXAMPLE
		# num_samples=3 num_queries=3 num_filters=4 qkeys=query_variation_call:read_depth;query_consequence:consequence;query_simple_population:population_frequency  fkeys=filter_variation_call:vcdp;vep_filter_consequence:consequence_severe;vep_filter_variant:vep_onekg;vep_filter_variant:vep_exac qkeyvalue=query_variation_call:read_depth>13;query_consequence:consequence>["'frameshift_variant'", "'incomplete_terminal_codon_variant'", "'inframe_deletion'", "'inframe_insertion'", "'initiator_codon_variant'", "'mature_miRNA_variant'", "'missense_variant'", "'splice_acceptor_variant'", "'splice_donor_variant'", "'start_lost'", "'5_prime_UTR_premature_start_codon_gain_variant'", "'stop_gained'", "'stop_lost'", "'stop_retained_variant'", "'TF_binding_site_variant'", "'TFBS_ablation'"];query_simple_population:population_frequency>0.15  resultsize=11 exceeded=false  max_result=5000 time=0.0753 experiment=1
		if !Query.logger.instance_variable_get(:@logdev).nil? && File.exist?(Query.logger.instance_variable_get(:@logdev).filename)
			File.open(Query.logger.instance_variable_get(:@logdev).filename, "r") do |fin|
				fin.each_line do |line|
					next unless line.index("STATRECORD")
					date, entries = line.strip.split(" STATRECORD ", 2)
					entries = entries.split("\t")
					entries = entries
						          .map{ |x|
							          key, value = x.split("=", 2).map(&:to_s)
							          next if value.nil?
							          if value[-1].last != "§"
								          value = value.split(";")
								          value = value.flatten(2)
								          value = value.join(" | ")
							          else
								          value = AquaQueryProcess.decode_from_log(value)
										  value = value.join(" | ") if value.is_a?(Array)
							          end
							          if html_sanitize
										  value = ERB::Util.html_escape value
							          end
							          [key.to_sym, value]
						          }.reject{|x| x.nil?}
					record = Hash[entries].merge({date: date})
					@query_log << record
				end
			end
		end
		# make sure all entries of the log have the same keys
		headers = @query_log.map{|rec| rec.keys}.flatten.uniq.sort
		@query_log.each do |rec|
			headers.each do |head|
				rec[head] = "" if rec[head].nil?
			end
		end
		@query_log
	end
	
end