# == Description
# Helper Module
module LongJobStatisticsHelper
	def statistics
		@queue_stats = {
				snupy: get_snupy_stats,
				annotation: get_annotation_stats
		}
		@user_stats = get_user_stats

	end

private
	def get_snupy_stats()
		queries = {}
		panels = {}
		panels2names = GenericGeneList.select([:id, :name, :title]).all.map do |pnl|
			[pnl.id, ((pnl.name || pnl.title) || pnl.id)]
		end
		panels2names = Hash[panels2names]
		result = LongJob.where(queue: 'snupy')
								 .where(method: 'query_aqua')
								 .where(success: true)
								 .map do |lj|
			opts = YAML.load(lj.parameter).first
			smpl_ids = opts["samples"]
			is_meta_experiment = ((lj.experiment_ids.first || 0 )< 0)?"1":"0"
			ljresult = lj.result_obj
			ljrec = {
				id: lj.id,
				date: lj.created_at,
				duration: (lj.finished_at - lj.started_at),
				wait_time: (lj.started_at - lj.created_at),
				size: ljresult.size,
				num_samples: smpl_ids.size,
				is_meta_experiment: is_meta_experiment
			}

			if (params["count_variants"]) then
				ljrec[:num_variants] = VariationCall.where(id: ljresult.load).pluck(:variation_id).uniq.size
			end

			if params["include_sample_info"] then
				smpls = Sample.where(id: smpl_ids)
				ljrec[:num_entity_groups] = smpls.reject{|s| s.entity_group_id.nil?}.map(&:id).uniq.size
				ljrec[:num_entities] = smpls.reject{|s| s.entity_id.nil?}.map(&:id).uniq.size
				ljrec[:num_specimen_probes] = smpls.reject{|s| s.specimen_probe_id.nil?}.map(&:id).uniq.size
			end

			allowed_klasses = [Aqua.queries[:simple].keys, Aqua.queries[:complex].keys].flatten
			opts['queries'].each do |qklassname, qnames|
				qklass = allowed_klasses.select{|qk| qk.name == qklassname.camelcase}.first
				next if qklass.nil?
				qnames.each do |qname, qconf|
					qsettings = ((qklass.configuration[qname.to_sym] || qklass.configuration[qname.to_s]) || qklass.configuration[qname])
					qsettings = {} if qsettings.nil?
					value = qconf['value']
					next if value.to_s == ""
					# check if the current query is a checkbox
					next if value.to_s == "0" and qsettings[:type] == :checkbox
					qconf['filters'].each do |fklass, fconf|
						fconf.each do |fname, factive|
							if factive.to_s == "1"
								# this part is only reached if there are filters that are active for the query
								if ljrec[qname].nil? then
									if (qsettings[:type] == :collection) then
										# handle the panel query in a special way
										if qname.to_s == "gene_id_panel" then
											if params["split_gene_id_panel"] then
												# retrieve missing panels
												get_panels(value.split(","), panels)
												value.split(",").each do |pnlid|
													panels[pnlid.to_i].each do |gene|
														ljrec["#{qname}_#{gene}"] = "1"
														queries["#{qname}_#{gene}"] = true
													end
												end
											else
												value = value.split(",").map {|pnlid|
													panels2names[pnlid.to_i]
												}.join(",")
											end
										end
										if params["split_values"] then
											value.split(",").each do |val|
												ljrec["#{qname}_#{val}"] = "1"
												queries["#{qname}_#{val}"] = true
											end
										end
									end
									ljrec[qname] = value
									queries[qname] = true
									if (params["include_combine"])
										ljrec["#{qname}.AND"] = (qconf['combine'].to_s.upcase == "AND")?"1":"0"
										queries["#{qname}.AND"] = true
									end
								end
								if params["show_filters"] then
									qfkey = "#{qname}.#{fname}"
									queries[qfkey] = true
									ljrec[qfkey] = 1
								end
							end
						end
					end
				end
			end
			ljrec
		end
		queries.keys.each do |qkey|
			result.each do |ljrec|
				ljrec[qkey] = 0 if ljrec[qkey].nil?
			end
		end
		result
	end

	def get_annotation_stats()
		result = LongJob.where(queue: 'annotation')
				.where(method: 'start')
				.where(success: true)
								 .map do |lj|
			ljrec = {
					id: lj.id,
					myid: lj.id,
					title: lj.title,
					date: lj.created_at,
					duration: (lj.finished_at - lj.started_at),
					wait_time: (lj.started_at - lj.created_at)
			}
			annotproc = YAML.load(lj.handle)
			ljrec["tools"] = (annotproc.tools.nil?)?"all":annotproc.tools.join(",")
			if params["include_vcf_info"] then
				vcfid = annotproc.vcfid
				vcf = VcfFile.where(id: vcfid).select(:id).first
				tag = vcf.tags.first
				if !vcf.nil? then
					ljrec["tag"] = (tag.nil?)?"NA":tag.value
				else
					ljrec["tag"] = "REMOVED (##{vcfid})"
				end
			end
			ljrec
		end
		result
	end

	def get_user_stats()
		result = User.all.map do |user|
			jobs = user.long_jobs.where('long_jobs.queue' => 'snupy').where('long_jobs.method' => 'query_aqua').where('long_jobs.success' => true)
			opts = jobs.map{|lj|YAML.load(lj.parameter).first}
			experiments = opts.map{|opt| opt["experiment"]}
			sizes = jobs.map{|lj| lj.result_obj.size}.to_scale
			durations = jobs.map{|lj| lj.finished_at - lj.started_at}.to_scale
			waitings = jobs.map{|lj| lj.started_at - lj.created_at}.to_scale
			samples = opts.map{|opt| opt["samples"]}
			num_samples = samples.map(&:size).to_scale
			cnt_samples = Hash.new(0)
			samples.flatten.each do |x|
				cnt_samples[x.to_i] += 1
			end
			top10 = cnt_samples.values.sort.reverse[0..10]
			top10 = Sample.where(id: cnt_samples.keys.select{|sid| top10.include?(cnt_samples[sid]) })
						   .map{|smpl| "#{smpl.name} (#{cnt_samples[smpl.id]})"}
			rec = {
					id: user.id,
					name: user.name,
					queries: jobs.size,
					experiments: experiments.uniq.size,
					avg_num_samples: num_samples.mean,
					var_num_samples: num_samples.variance,
					avg_duration: durations.mean,
					var_duration: durations.variance,
					avg_wait_time: waitings.mean,
					var_wait_time: waitings.variance,
					avg_result_size: sizes.mean,
					var_result_size: sizes.variance,
					max_result_size: sizes.max,
					min_result_size: sizes.min,
					top10: top10
			}
			rec
		end
		result
	end

	def get_panels(pnlids, cache)
		pnlids.each do |pnlid|
			next unless cache[pnlid.to_i] == nil
			pnl = GenericGeneList.where(id: pnlid).first
			if !pnl.nil? then
				cache[pnlid.to_i] = pnl.genes
			else
				cache[pnlid.to_i] = []
			end
		end
	end
end
