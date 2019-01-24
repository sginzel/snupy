module ExperimentsQueryGeneratorHelper
	
	def query_generator
		Aqua._reload() if Rails.env == "development"
		
		@experiment = Experiment.find(params[:id])
		@entities = find_subjects
		if params["commit"] == "LOAD" and params[:long_job_id].to_s == "" then
			redirect_to query_generator_experiment_path(@experiment)
			return
		end

		@generators = QueryGenerator.descendants.map{|qg|
			qg
		}
		if !params[:entities].nil? then
			@selected_entities = @entities.where("entities.id" => params[:entities])
		else
			@selected_entities = Entity.joins(:tags).where("1 = 0")
		end
		@samples = []

		@long_job = LongJob.new()
		if params[:commit] == "OK" and !params[:entities].nil? then
			opts = params.dup
			opts.delete "utf8"
			opts.delete "queue_name"
			opts.delete "authenticity_token"
			opts.delete "format"
			opts.delete "commit"
			opts.delete "commit_action"
			opts[:user] = current_user()
			opts["user"] = current_user()
			opts[:experiment] = @experiment
			opts["experiment"] = @experiment
			# submit parametes to the query generator process

			if params[:jobtitle].to_s == "" then
				job_title = "QGen: [#{(params[:query_generators] || {}).keys.select{|k| (params[:query_generators][k] || {})[:selected].to_s == "1"}.join(",")}] "
	
				myentities = Entity.where(id: params[:entities]).pluck(:name)
				someid = Time.now.to_i.to_s(36).upcase
				if myentities.size > 4 then
					job_title << " for #{myentities.size} Entities (#{someid})"
				else
					job_title << " for #{myentities.join(",")} (#{someid})"
				end
			else
				job_title = params[:jobtitle]
			end
			
			qgp = QueryGeneratorProcess.new(Entity.find(params[:entities]),
											params[:query_generators],
											opts)
			@long_job = LongJob.create_job({
												 title: job_title,
												 handle: qgp,
												 method: :generate_query,
												 user: http_remote_user(),
												 queue: "snupy"
											 }, true)
			# make sure the job is redirected properly
			@long_job.result_view = query_generator_experiment_url(
				@experiment,
				commit: "LOAD",
				long_job_id: @long_job.id,
				format: "html"
			)
			@long_job.save
			@experiment.long_jobs << @long_job
		elsif params[:commit] == "LOAD" and !params[:long_job_id].nil? then
			@long_job = LongJob.find(params[:long_job_id])
			# the results are stored in a object dump and have to be loaded
			@results = {}
			results = YAML.load(@long_job.result_obj)
			@result_summary = results.delete(:_summary)
			@result_params = (results.delete(:_params) || {})

			@entities = Entity.find(@result_params[:entities])
			if ((params[:generator_summary] || []).size > 0) then
				records_to_load = {}
				params[:generator_summary].each do |recid|
					id, generator = recid.split('_', 2)
					records_to_load[generator] ||= Hash.new(false)
					records_to_load[generator][id] = true
				end
				results.keys.each do |generator|
					next if records_to_load[generator].nil?
					@results[generator] = {result: [], colors: {}}
					results[generator].keys.each do |entity|
						next if entity.is_a?(Symbol) # required to save the :_config that was used to start the generator
						next unless records_to_load[generator][entity.id.to_s]
						@samples += entity.entity_group.sample_ids
						varcallids = results[generator][entity][:varcallids]
						next if varcallids.nil? or varcallids.size == 0
						aaggprocess = AquaAggregationProcess.new(@experiment, varcallids)
						colors = Aggregation.get_aggregation_colors()
						ent_result = aaggprocess.start(results[generator][entity][:parameters])
						ent_result.each{|rec| rec["SUBJECT"] = entity.name}
						@results[generator][:result] += ent_result
						@results[generator][:colors] = @results[generator][:colors].merge(colors)
					end
				end
				@samples.uniq!
			end
		elsif params[:commit] == "DELETE" and !params[:long_job_id].nil? then
			LongJob.destroy(params[:long_job_id])
		end
		@long_jobs = @experiment.long_jobs.where("long_jobs.method" => "generate_query").where("STATUS = 'DONE'")
		@entities = @entities.map do |ent|
			ret = ent.attributes
			ret["parents"] = (ent.parents() || []).map(&:name)
			ret["siblings"] = (ent.siblings() || []).map(&:name)
			ret["tags"] = ent.tags.map(&:value)
			ret["vcf.tags"] = ent.vcf_files.map(&:tags)
			ret
		end
		
	end
	
private
	def find_subjects
		@experiment.entities.joins(:tags).where("tags.value != 'shared control' AND tags.category = 'CLASS'").uniq
	end

	def get_params(*args)
		val = nil
		paramsdup = params.dup
		while args.size > 0
			key = args.shift
			val = paramsdup[key]
			if val.nil? then
				return nil
			end
			paramsdup = val
		end
		val
	end

end
