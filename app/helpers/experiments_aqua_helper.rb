module ExperimentsAquaHelper
	include AquaParameterHelper
	def aqua_meta
		# create meta experiment for user?
		experiment = Experiment.where(id:
			Experiment.get_meta_experiment_id(
					User.find(params[:user] || current_user),
					Organism.find(params[:organism])
			)
		).first
		if experiment.nil? then
			refresh_samples = true
		else
			refresh_samples = (Time.now - experiment.updated_at) > (Time.now - 24.hours.ago)
		end
		experiment = Experiment.meta_experiment_for(User.find(params[:user] || current_user), Organism.find(params[:organism]), refresh_samples)
		redirect_to action: "aqua", id: experiment.id
	end

	def aqua
		## TODO: This might not be always optimal, but is required during Development
		if (Rails.env == "development") then
			d "Refreshin Aqua from ExperimentsController#aqua"
			ActiveRecord::Base.connection.execute("RESET QUERY CACHE;") # resetting the query cache makes it easier to do timing tests.
			Aqua._reload()
		end
	#SnupyAgain::Profiler.profile("experiment_controller_aqua") {
		if params[:id].to_i.to_s == params[:id].to_s then
			@experiment = Experiment.find(params[:id])
		else
			@experiment = Experiment.find_by_name(params[:id])
			if !@experiment.nil? then
				redirect_to action: "aqua", id: @experiment.id
			else
				alert_and_back_or_redirect(message = "Project #{params[:id]} not found", url = "/experiments")
			end
			return true
		end

	## if the experiment is a meta experiment, make sure the last update to the samples was not longer than 24 hours ago
		if @experiment.id < 0 and (Time.now - @experiment.updated_at) > (Time.now - 24.hours.ago) then
			uid = (@experiment.id / 100000.0).ceil * -1
			oid = (@experiment.id + (uid * 100000.0)).abs
			flash[:notice] = "Meta Project was updated. "
			@experiment = Experiment.meta_experiment_for(User.find(uid), Organism.find(oid), true)
		end

		begin
			# @experiment = Experiment.find(params[:id])
			@long_jobs = @experiment.long_jobs
			@samples = @experiment.samples || []
			if @experiment.entity_groups.size > 0 then
				@samples += Sample.joins(:entity_group).where("entity_groups.id" => @experiment.entity_group_ids) || []
				@samples.uniq!
			end

			# AQUA
			@queries = Aqua.queries
			@queries = @queries[:simple].merge(@queries[:complex])
			@aggregations = Aqua.aggregations
			@attr_aggregations = Aqua.attribute_aggregations
			@group_aggregations = Aqua.group_aggregations
			@qparams = Aqua.parse_params(params)

			# we have to make sure that research managers dont give access to the meta project to unpriviledged users
			# If _managers do that users gain access to all samples of the institutions where they are listed as users
			# As these project will not show up in the list of available projects to the normal users
			# a _manager needs to send a URL link to the meta experiment.
			# So without intention from a _manager users will not gain access
			# @samples = @samples & current_user.visible(Sample)

			# make sure the user only sees samples that he can access through his experiments
			# @samples = @samples & Sample.joins(:experiments).where("experiments.id" => current_user.visible(Experiment))
			# @selected_samples = @samples.select{|s|(params[:samples] || []).include?(s.id.to_s)}
			@tag_formula_message = nil
			@tag_formula_error = nil
			if (params[:tag_formula].to_s == "" or params[:commit] == "OK") then
				smplids = (params[:samples] || params[:sample_ids])
			else
				begin
					smplids = SnupyAgain::TagExpression.parse(params[:tag_formula]).values.flatten.map(&:id)
				rescue SnupyAgain::ExpressionParseException => e
					smplids = []
					@tag_formula_error = e.message
				end
			end
			if (smplids || []).size > 0 then
				@selected_samples = @experiment.associated_samples.where("samples.id" => smplids)
				#@selected_samples = @experiment.samples.where("samples.id" => smplids).pluck("samples.id")
				#@selected_samples = @selected_samples | Experiment.joins(:entity_groups => [:samples])
				#																						.where("experiments.id" => @experiment)
				#																						.where("samples.id" => smplids).pluck("samples.id")
				#@selected_samples = Sample.where(id: @selected_samples.uniq)
				@tag_formula_message = "#{@selected_samples.size} samples pre-selected" unless params[:tag_formula].nil?
			else
				@selected_samples = Sample.where(" 1 = 0 ")
			end
			# selected samples vs actually selectable samples
			flash[:notice] = "" if flash[:notice].nil? if !smplids.nil?
			flash[:notice] << "#{@selected_samples.size} samples selected;" if !smplids.nil?

			# sort the queries by their priority - and remove queries that have no filter
			# UPDATE: SORTING now happens inside the view, because it is only relevant there.
			if (1 == 0) then
				sorted_queries = {}
				@queries.keys.sort{|x,y|
					x.configuration.map{|qname, qconf| qconf[:priority]}.min <=> y.configuration.map{|qname, qconf| qconf[:priority]}.min
				}.each do |qklass|
					next if qklass.filters.size == 0
					sorted_queries[qklass] = {}
					@queries[qklass].keys.sort{|x,y|
						qklass.configuration_for(x)[:priority] <=> qklass.configuration_for(y)[:priority]
					}.each do |qname|
						next if (qklass.filters(qname).nil? || qklass.filters(qname).size == 0)
						next if (qklass.filters(qname).all?{|f| not f.applicable?})
						next if qklass.configuration_for(qname)[:batch]
						# d "#{qklass} => #{qname} => #{qklass.filters(qname).size}"
						sorted_queries[qklass][qname] = @queries[qklass][qname]
					end
				end
				@queries = sorted_queries
			else
				new_queries = {}
				@queries.keys.each do |qklass|
					next if qklass.filters.size == 0
					new_queries[qklass] = {}
					@queries[qklass].keys.each do |qname|
						next if (qklass.filters(qname).nil? || qklass.filters(qname).size == 0)
						next if (qklass.filters(qname).all?{|f| not f.applicable?})
						next if qklass.configuration_for(qname)[:batch]
						# d "#{qklass} => #{qname} => #{qklass.filters(qname).size}"
						new_queries[qklass][qname] = @queries[qklass][qname]
					end
				end
				@queries = new_queries
			end

			@column2color = {}
			@attr_aggregations.each do |aklass, aconfs|
				aconfs.each do |aname, aconf|
					next if aconf[:color].nil?
					if aconf[:color].is_a?(Hash) then
						@column2color.merge!(aconf[:color])
					else
						@column2color.merge!({aconf[:colname] => aconf[:color]})
					end
				end
			end
			@column2recordcolor = {}
			@attr_aggregations.each do |aklass, aconfs|
				aconfs.each do |aname, aconf|
					next if aconf[:record_color].nil?
					if aconf[:record_color].is_a?(Hash) then
						@column2recordcolor.merge!(aconf[:record_color])
					else
						@column2recordcolor.merge!({aconf[:colname] => aconf[:record_color]})
					end
				end
			end
			if !current_user.is_admin then
				@unfinished_samples = @samples.select{|s| !s.ready_to_query?}
				@samples = @samples.reject{|s| !s.ready_to_query?}
			else
				@unfinished_samples = @samples.select{|s| !s.status == "DONE"}
				@samples = @samples.reject{|s| !s.status == "DONE"}
			end

			# @samples = Sample.where(id: @samples)
			#							 .includes([:tags,
			#										{:entity => :tags},
			#										{:entity_group => :tags},
			#										{:vcf_file_nodata => :tags}, :experiments, :institution])
			@samples = Sample.where(id: @samples)
				           .includes([:tags,
				                      {:entity => :tags},
				                      {:entity_group => :tags},
				                      {:specimen_probe => :tags},
				                      {:vcf_file_nodata => :tags}, :experiments, :institution])
			# make the selected samples appear on top of the list.
			sample_selected = Hash[@selected_samples.map{|s| [s.id, true]}]
			sample_selected.default = false
			@samples.sort!{|s1, s2|
				if (!sample_selected[s1.id] && !sample_selected[s2.id]) or (sample_selected[s1.id] && sample_selected[s2.id]) then
					s1.name <=> s2.name
				else
					(sample_selected[s1.id] && !sample_selected[s2.id])?(-1):( 1)
				end
			}
			
			## return aqua JSON if so desired
			if params[:format].to_s == "aqua" then
				keys = _parse_keys(params)
				parameters = _build_query(params)
				@result = [{
					id: -1,
					date: Time.now,
					parameters: parameters.pretty_inspect.gsub(" ", "&nbsp").gsub("\n", "<br>"),
					qkey: keys[:qkey].pretty_inspect.gsub(" ", "&nbsp").gsub("\n", "<br>"),
					fkey: keys[:fkey].pretty_inspect.gsub(" ", "&nbsp").gsub("\n", "<br>"),
					akey: keys[:akey].pretty_inspect.gsub(" ", "&nbsp").gsub("\n", "<br>"),
					"r-parameters" => "
list(
  filters = c(#{keys[:fkey].map{|f| "'#{f}'"}.join(", ")}),
  queries = list(
    #{keys[:qkey].map{|qkey, qconf| "'#{qkey}' = list(value = #{qconf[:value].to_s}, combine = '#{qconf[:combine]}')"}.join(",\n")}
  ),
  aggregations = c(#{keys[:akey].map{|a| "'#{a}'"}.join(", ")})
)
".html_safe.pretty_inspect.gsub(" ", "&nbsp").gsub("\\n", "<br>").gsub("\n", "<br>")
				}]
				flash[:notice] = "Only showing parameters to use in API"
				# render action: "aqua"
				# alert_and_back_or_redirect(aqua_error.split("\n")[0..3].join("<br>").html_safe)
				return
			end

			varcallids = []
			if params[:commit] == "OK"
				if params[:commit_action] == "query" || params[:commit_action] == "newjob"
					if @selected_samples.size == 0 then
						flash[:alert] = "No Samples selected"
						Aqua.log_warn("No Samples selected")
						Aqua.log_warn(params.pretty_inspect)
						render status: 400, action: "aqua"
						# alert_and_back_or_redirect("No Samples selected.")
						return
					end
					opts = params.dup
					opts.delete "utf8"
					opts.delete "queue_name"
					opts.delete "authenticity_token"
					opts.delete "format"
					opts.delete "commit"
					opts.delete "commit_action"
					opts[:user] = current_user()
					opts[:experiment] = @experiment
					opts["user"] = current_user()
					opts["experiment"] = @experiment

					# TODO: When we create new job we should refactor the AquaQueryProcess so that it only
					#       takes the actual queries as parameters. Doing so we can have different
					#       attributes selected for the same query. Right now only the combination of both yield
					#       the md5sum required to detect the result.
					#       Also: When storing the variation_calls ids we should considers some for of compression.
					if params[:commit_action] == "query" then
						# qp = AquaQueryProcess.new(@experiment.id)
						# varcallids = qp.start(opts)
						varcallids = @experiment.query_aqua(opts, binding).load()
					else # create a job
						@long_job = LongJob.create_job({
															 title: opts[:jobname],
															 handle: @experiment,
															 method: :query_aqua,
															 user: current_user.name,
															 queue: "snupy"
															 }, true, opts)
						# make sure the job is redirected properly
						@long_job.result_view = aqua_experiment_url(
								@experiment,
								commit: "OK",
								commit_action: "load",
								jobname_select: @long_job.id,
								format: "html"
						)
						@long_job.save
						@experiment.long_jobs << @long_job
						if @long_job.success then # if we get a job back from the create_query method then it migh already be a success
							flash[:notice] = "result loaded from #{@long_job.title}"
							# varcallids = AquaResult.fromJSON(@long_job.result_json).load()
							# noinspection RubyArgCount
							varcallids = @long_job.result_obj.load()
						else
							varcallids = []
						end
					end

				elsif params[:commit_action] == "load" || params[:commit_action] == "delete" then
					begin
						@long_job = LongJob.joins(:experiments)
														.where("experiments.id" => @experiment)
														.where("long_jobs.id" => (params[:jobname] || params[:jobname_select]))
						raise ActiveRecord::RecordNotFound if @long_job.size == 0 || @long_job.size > 1
						@long_job = @long_job.first
						## check if the long_job is not a result from another run
						ljparams = ((YAML.load(@long_job.parameter) || []).first || {})
						# in case nothing was given just try to work with the parameters which were submitted
						if ljparams.size == 0 then
							ljparams = params.dup
						end
						ljparams.keys.each{|k| ljparams[k.to_sym] = ljparams[k] unless ljparams[k.to_sym]}
						if params[:commit_action] == "load" then
							aqua_result = @long_job.result_obj
							if !aqua_result.is_a? AquaResult then
								alert_and_back_or_redirect("Job is too old.")
								return
							end
							varcallids = (aqua_result).load()
							opts = ljparams
							if not params[:aggregations].nil? then
								opts["aggregations"] = {"attribute" => {}} if opts["aggregations"].nil?
								opts["aggregations"]["attribute"].merge!(params[:aggregations]["attribute"])
							end

							params["samples"] = ljparams["samples"]
							params["queries"] = ljparams["queries"]
							params["user"] = current_user()
							params["experiment"] = @experiment
							params[:user] = current_user()
							params[:experiment] = @experiment
							
							# @selected_samples = @experiment.samples.where("samples.id" => params["samples"])
							@selected_samples = Sample.where("samples.id" => params["samples"])
							#params_submitted = params.dup()
							#params.merge!(ljparams)
							#opts = params.dup()
							#opts["aggregations"]["attribute"].merge(params_submitted["aggregations"]["attribute"]) unless params_submitted["aggregations"].nil?
						elsif params[:commit_action] == "delete"
							@experiment.long_jobs.delete(@long_job)
							@long_job.delete
							@long_job = nil
							@long_jobs = @experiment.long_jobs ## refresh job list
						end

					rescue ActiveRecord::RecordNotFound => e
						alert_and_back_or_redirect("Job does not exist.")
						return
					end
				else
					# unknown action
					alert_and_back_or_redirect("Unknown action.")
					return
				end
				aqua_error = Aqua.last_error
				if !aqua_error.nil? then
					flash[:alert] = aqua_error.split("\n")[0..3].join("<br>").html_safe
					render action: "aqua"
					# alert_and_back_or_redirect(aqua_error.split("\n")[0..3].join("<br>").html_safe)
					return
				end
				if varcallids.size > 0
					agp = AquaAggregationProcess.new(@experiment.id, varcallids, binding)
					@result = agp.start(opts)
				else
					@result = []
				end
				aqua_error = Aqua.last_error
				if !aqua_error.nil? then
					flash[:alert] = aqua_error.split("\n")[0..3].join("<br>").html_safe
					render action: "aqua"
					# alert_and_back_or_redirect(aqua_error.split("\n")[0..3].join("<br>").html_safe)
					return
				end
			end # end of 'if params[:commit] == "OK"'

				## from old query method
				#format.vcf  {
				#			filename = ((@experiment.title != "")?(@experiment.title):(@experiment.name)).to_s + ".csv"
				#			filename = @long_job.title + ".csv" unless @long_job.nil?
				#			render file: "experiments/query.vcf.erb",
				#				   locals: {
				#						   filters: @query_filter,
				#						   samples: @selected_samples
				#				   }
				#		}
				#}
		rescue RuntimeError => e
			if Rails.env == "production"
				msg = "Something went wrong during the query. Please contact an admin.".html_safe
				now = Time.now.to_s
				Aqua.log_error("(#{now}) Aqua process failed")
				Aqua.log_error("(#{now}) #{e.message}")
				Aqua.log_error("(#{now}) #{e.backtrace.join("\n")}")
				flash[:alert] = msg
				render action: "aqua"
				# alert_and_back_or_redirect(message = msg, url = aqua_experiment_path(params[:id]))
				return true
			else
				raise e
			end
		end
	end

	# lookup variations in other experiments
	def details
		#d "detaiul"
		#d params

		ids = ((params[:ids] || params[:variation_call_id])|| params[:variation_call_ids])
		if ids.is_a?(Array) then
			ids = ids.map{|id| id.split(" | ")}.flatten
		end
		ids = [ids] if !ids.nil? and !ids.is_a?(Array)
		variation_ids = (params[:variation_ids] || params[:variation_id])
		if variation_ids.is_a?(Array) then
			variation_ids = variation_ids.map{|id| id.split(" | ")}.flatten
		end
		variation_ids = [variation_ids] if !variation_ids.nil? and !variation_ids.is_a?(Array)
		
		all_tags = !params[:tags].nil?
		
		#if ((ids || []).size > 5000) then
		#	render text: "Not more than 5000 variations allowed"
		#	return true
		#end
		
		@details = []
		@variation_ids = []
		@variation_ids += VariationCall.where(id: ids).pluck(:variation_id).uniq unless ids.nil?
		@variation_ids += variation_ids unless variation_ids.nil?
		
		
		if (!params[:experiment].nil?) then
			@experiment = Experiment.find(params[:experiment])
		else
			@experiment = Experiment.new
		end
		
		@samples = (current_user.reviewable(Sample) + current_user.visible(Sample) + @experiment.samples).uniq
		# prepare entity lookup
		@entity2tags = {}
		@entities = (current_user.reviewable(Entity) + current_user.visible(Entity) + @experiment.entities).uniq
		@entities = Entity.joins(:tags).includes(:tags).where("entities.id" => @entities)
		@entities.uniq.each do |ent|
			if (!all_tags) then
				@entity2tags[ent.id.to_i] = {
					is_control: ent.tags.any?{|t| t.value == "shared control"},
					disease: ent.tags.select{|t| t.category == "DISEASE"}.map(&:value)
				}
			else
				@entity2tags[ent.id.to_i] = {
					is_control: ent.tags.any?{|t| t.value == "shared control"},
					disease: ent.tags.map{|t| "#{t.category}/#{t.value}" }
				}
			end
		end
		@entity2tags[nil] = {is_control: nil, disease: ["No associated entity. Unknown."]}
		diseases = @entity2tags.map{|entid, val| val[:disease]}.flatten.uniq.sort
		diseases_with_hits = Hash[diseases.map{|dname| [dname, false]}]
		details = {}
		# add coordinates and initilize values
		Aqua.scope_to_array(
			Variation.where(id: @variation_ids).joins([:alteration, :region]).includes([:region, :alteration]), true
		){|rec|
			details[rec['variations.id']] = {} if details[rec['variations.id']].nil?
			details[rec['variations.id']]['chr'] = rec['regions.name']
			details[rec['variations.id']]['from'] = rec['regions.start']
			details[rec['variations.id']]['to'] = rec['regions.stop']
			details[rec['variations.id']]['ref'] = rec['alterations.ref']
			details[rec['variations.id']]['alt'] = rec['alterations.alt']
			details[rec['variations.id']]['id'] = []
			details[rec['variations.id']]['samples'] = []
			details[rec['variations.id']]['specimen_probes'] = []
			details[rec['variations.id']]['entities'] = []
			details[rec['variations.id']]['entity_groups'] = []
			details[rec['variations.id']]['num.missing_association'] = 0
			details[rec['variations.id']]['num.case'] = 0
			details[rec['variations.id']]['num.control'] = 0
			diseases.each do |disease_name|
				details[rec['variations.id']][disease_name] = []
			end
			details[rec['variations.id']]['variation_id'] = rec['variations.id']
			
		}
		# add number of entities and such
		Aqua.scope_to_array(
			VariationCall.joins(:sample).where(sample_id: @samples).where(variation_id: @variation_ids)
			.select([
				"variation_calls.variation_id AS variation_id",
				"variation_calls.id AS variation_call_id",
				"samples.id AS sample_id",
				"samples.specimen_probe_id AS specimen_probe_id",
				"samples.entity_id AS entity_id",
				"samples.entity_group_id AS entity_group_id"
			])
		){|rec|
			details[rec['variation_id']] = {} if details[rec['variation_id']].nil?
			# initilization of more fields
			if (details[rec['variation_id']]['id'].nil?)
			
			end
			details[rec['variation_id']]['id'] << rec['variation_call_id']
			details[rec['variation_id']]['samples'] << rec['sample_id']
			details[rec['variation_id']]['specimen_probes'] << rec['specimen_probe_id']
			details[rec['variation_id']]['entities'] << rec['entity_id']
			details[rec['variation_id']]['entity_groups'] << rec['entity_group_id']
		}
		# add diseases and such
		details.each do |varid, record|
			record['num.missing_association'] = record['specimen_probes'].select{|x| x.nil?}.size
			record['entities'].uniq.each do |entid|
				next if entid.nil?
				record['num.case'] += 1    unless (@entity2tags[entid] || {})[:is_control]
				record['num.control'] += 1 if (@entity2tags[entid] || {})[:is_control]
				# add diseases
				if !@entity2tags[entid][:is_control]
					@entity2tags[entid][:disease].each do |disease_name|
						diseases_with_hits[disease_name] = true
						record[disease_name] << entid
					end
				end
			end
		end
		# remove disease columns that do not have any hits
		diseases_with_hits.each do |disease_name, was_hit|
			if !was_hit then
				details.each do |varid, record|
					record.delete(disease_name)
				end
			end
		end
		
		details.each do |varid, record|
			record.keys.each do |k|
				record[k] = record[k].uniq if record[k].is_a?(Array)
				if (k != 'id')
					record[k] = record[k].reject(&:nil?).size if record[k].is_a?(Array)
				else
					record[k] = record[k].uniq.join(" | ")
				end
			end
		end
		
		@details = details.values.flatten
		
		respond_to do |format|
			format.html {
				render partial: "details", locals:{
						details: @details,
						params: params
				}
			}
			format.csv {
				render partial: "details", locals:{
					details: @details,
					params: params
				}
			}
			format.json {
				render partial: "details", locals:{
						details: @details,
						params: params
				}
			}
			# format.json { render json: @details }
		end
	end
	
	def more_details()
		ids = params["ajax_params"]["ids"]
		@tbl = []
		if (ids)
			@variation_ids = VariationCall.where(id: ids).pluck(:variation_id).uniq
			@experiment = Experiment.find(params["ajax_params"][:experiment_id])
			@samples = (current_user.reviewable(Sample) + current_user.visible(Sample) + @experiment.samples).uniq
			# prepare entity lookup
			@entity2tags = {}
			@entities = (current_user.reviewable(Entity) + current_user.visible(Entity) + @experiment.entities).uniq
			@entities = Entity.joins(:tags).includes(:tags).where("entities.id" => @entities)
			@entities.uniq.each do |ent|
				@entity2tags[ent.id.to_i] = {
					is_control: ent.tags.any?{|t| t.value == "shared control"},
					disease: ent.tags.select{|t| t.category == "DISEASE"}.map(&:value)
				}
			end
			@entity2tags[nil] = {is_control: "no entity associated", disease: "No association"}
			details = {}
			Aqua.scope_to_array(
				VariationCall.joins(:sample).where(sample_id: @samples).where(variation_id: @variation_ids),
				true
			){|rec|
				details[rec['variation_calls.id']] = rec
				details[rec['variation_calls.id']]["is.control"] = @entity2tags[rec["samples.entity_id"]][:is_control]
				details[rec['variation_calls.id']]["disease"] = @entity2tags[rec["samples.entity_id"]][:disease]
			}
			@tbl = details.values.flatten
		end
		
		respond_to do |format|
			format.html {
				render partial: "more_details", locals:{
					details: @tbl,
					params: params
				}
			}
			format.json {
				render partial: "details", locals:{
					details: @tbl,
					params: params
				}
			}
			# format.json { render json: @details }
		end
	end

	#show interactions after query process
	def interactions
		if !params[:ids].nil?
			require_params = {
					ids: params[:ids],
					experiment: params[:experiment],
					list: [" ", " "] + current_user.generic_gene_lists.map{|l| [l.name, l.id] },
					include_interaction_between_list_items: [["Yes", "yes"], ["No", "no"]],
					threshold: "950",
					include_text_mining: [["No", "no"], ["Yes", "yes"]],
					dimension: "1024,786",
					queries: params[:queries],
					aggregations: params[:aggregations]
					# format: [["HTML", "html"], ["GRAPHML", "graphml"]]
			}
			if determine_missing_params(require_params).size > 0 then
				render_table_details_params(require_params)
			else
				interaction_data = view_context.get_interaction_data(params)
				# also find details
				ids = params[:ids]
				if ids.is_a?(Array) then
					ids = ids.map{|id| id.split(" | ")}.flatten
				end
				@variation_calls = VariationCall.find(ids)
				@variations = Variation.joins(:variation_calls).where("variation_calls.id" => ids)
				@experiment = Experiment.find(params[:experiment])
				@samples = @experiment.samples.uniq
				
				# TODO these details should be a list of variant calls and gene names, so users can select entries of interest.
				@details = Aqua.scope_to_array(
					VariationCall.where(sample_id: @samples)
						.where(variation_id: @variations)
						.joins(:sample)
						.joins(variation: [:alteration, :region])
						.includes(variation: [:region, :alteration]), true
				).first(100)
				respond_to do |format|
					format.html {
						render partial: "interactions", locals: interaction_data
					}
				end
			end
		else
			render text: "No entries selected"
		end
	end

	#show details of gene by ppi-graph/show interactions results
	def interaction_details
		@gene_table_id  = "gene_table_#{Time.now().to_f.to_s.gsub(".", "")}"
		@gene_symbol = params[:alias]
		@gene_id = params[:gene]
		@gene_cards = ""
		@varids = params[:url].to_s.gsub("VARIDS: ", "").split(" | ")
		
		@experiment = Experiment.find(params[:experiment])
		if @varids.size > 0 then
			@variations = Variation.where(id: @varids)
		else
			@variations = Vep::Ensembl.where("gene_id = '#{params[:alias]}' OR gene_symbol = '#{params[:alias]}'")
							  .where(:organism_id => @experiment.organism)
							  .pluck(:variation_id)
		end
		

		if @variations.size > 0
			@details = Aqua.scope_to_array(
					Vep::Ensembl.joins(:samples)
							.joins(variation: [:alteration, :region])
							.where("variation_calls.sample_id" => @experiment.samples)
							.where(Vep::Ensembl.table_name + ".variation_id" => @variations)
							.select(["variations.id as `variations.id`","regions.name as chr", "regions.start", "regions.stop",
									 "alterations.ref", "alterations.alt",
									 Vep::Ensembl.table_name + ".gene_symbol", Vep::Ensembl.table_name + ".gene_id", Vep::Ensembl.table_name + ".consequence",
									 "samples.name as sample_name", "samples.id", "variation_calls.gt", "variation_calls.dp", "variation_calls.alt_reads / (variation_calls.ref_reads + variation_calls.alt_reads) as baf"
									]),
					false
			).uniq
		else
			@details = [{info: "No variants found.", Vep::Ensembl.table_name + ".variation_id" => 0}]
		end
		@gene_details_table_id  = "gene_details_table_id_#{Time.now().to_f.to_s.gsub(".", "")}"
		@gene_details = {
				gene: params[:genes],
				alias: params[:alias],
				group: params[:group]

		}
		
		render partial: "interaction_details", locals: {
				gene_table_id: @gene_table_id,
				gene_symbol: @gene_symbol,
				gene_cards: @gene_cards,
				experiment: @experiment,
				details: @details,
				gene_details_table_id: @gene_details_table_id,
				gene_details: @gene_details
		}
	end
end