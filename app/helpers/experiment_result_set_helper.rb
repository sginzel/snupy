module ExperimentResultSetHelper
	
	
	# Gets a list of variation call ids, selected by the user from the results. Prompts for a name and stores a
	# LongJob record associated to the given experiment that can be used to load the result set again.
	def save_resultset
		ids = params[:ids]
		if ids.is_a?(Array) then
			ids = ids.map {|id| id.split(" | ")}.flatten.map(&:to_i)
		end
		queries = YAML.load(params[:queries])
		aggregations = YAML.load(params[:aggregations])
		require_params  = {
			ids:                 params[:ids],
			samples: params[:samples],
			experiment: params[:experiment],
			queries: queries.to_yaml,
			aggregations: aggregations.to_yaml,
			name:    ""
		}
		if determine_missing_params(require_params).size > 0 then
			render_table_details_params(require_params)
		else
			experiment = Experiment.find(params[:experiment])
			result = AquaResult.new(ids)
			checksum = Digest::MD5.hexdigest(ids.sort.join(","))
			lj = LongJob.where(checksum: checksum, status: "SAVED").first
			if lj.nil?
				lj = LongJob.new({
									 delayed_job_id: nil,
									 title: "[RESULTSET] #{params[:name]} (#{Time.now.to_i.to_s(36).upcase})",
									 user: current_user.name,
									 handle: nil,
									 method: nil,
									 parameter: [{"samples" => params[:samples], "queries" => queries, "aggregations" => aggregations}].to_yaml,
									 result: LongJob.marshal_and_zip(result),
									 result_view: lj,
									 status: LongJob::STORED,
									 status_view: nil,
									 started_at: Time.now,
									 finished_at: Time.now,
									 success: true,
									 checksum: checksum,
									 error: nil,
									 queue: 'stored_resultsets'
								 })
				if (lj.save)
					lj.result_view = aqua_experiment_url(
						experiment,
						commit: "OK",
						commit_action: "load",
						jobname: lj.id,
						format: "html"
					)
					lj.save!
					experiment.long_jobs << lj
					if (experiment.long_jobs.include?(lj))
						render text: "Save successful"
					else
						lj.destroy # make sure it wont be in the way
						render text: "Cannot associate result to experiment", status: 500
					end
				else
					render text: "Cannot save result", status: 500
				end
			else
				render text: "The same result was previously stored as '#{lj.title}'. Not storing it a second time.", status: 500
			end
		end
	end

end