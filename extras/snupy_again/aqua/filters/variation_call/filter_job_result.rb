class FilterJobResult < SimpleFilter
	create_filter_for QueryJobResult, :job_result,
					  name: :part_of_job_varcall,
					  label: "Overlap with result (same samples required)",
						filter_method: :present_in_job_varcall,
						collection_method: :list_jobs,
						organism: [organisms(:human), organisms(:mouse)], 
						requires: {VariationCall => [:id]},
						checked: false,
						tool: Annotation
	
	create_filter_for QueryJobResult, :job_result,
					  name: :part_of_job_variant,
					  label: "Overlap with variants (different samples possible)",
						filter_method: :present_in_job_variant,
						collection_method: :list_jobs,
						organism: [organisms(:human), organisms(:mouse)], 
						requires: {VariationCall => [:variation_id]},
						tool: Annotation
	
	create_filter_for QueryJobResult, :job_result_not,
					  name: :not_part_of_job_varcall,
					  label: "No overlap with result (same samples required)",
						filter_method: :not_present_in_job_varcall,
						collection_method: :list_jobs,
						organism: [organisms(:human), organisms(:mouse)], 
						requires: {VariationCall => [:id]},
						checked: false,
						tool: Annotation
	
	create_filter_for QueryJobResult, :job_result_not,
					  name: :not_part_of_job_variant,
					  label: "No overlap with variants (different samples possible)",
						filter_method: :not_present_in_job_variant,
						collection_method: :list_jobs,
						organism: [organisms(:human), organisms(:mouse)], 
						requires: {VariationCall => [:variation_id]},
						tool: Annotation
	
	def present_in_job_varcall(values)
		ljs = LongJob.where(id: values)
		ljs = ljs.map{|lj| lj.result_obj}.select{|aqua_result|aqua_result.is_a?(AquaResult)}
		varcallids = ljs.map{|aqua_result| aqua_result.load}.flatten.uniq
		return nil if varcallids.size == 0
		"variation_calls.id IN (#{varcallids.join(",")})"
	end
	
	def present_in_job_variant(values)
		ljs = LongJob.where(id: values)
		ljs = ljs.map{|lj| lj.result_obj}.select{|aqua_result|aqua_result.is_a?(AquaResult)}
		varcallids = ljs.map{|aqua_result| aqua_result.load}.flatten.uniq
		varids = VariationCall.where(id: varcallids).pluck(:variation_id).uniq
		return nil if varcallids.size == 0 or varids.size == 0
		Aqua.quick_in "variation_calls.variation_id", varids, "variations"
	end
	
	def not_present_in_job_varcall(values)
		ljs = LongJob.where(id: values)
		ljs = ljs.map{|lj| lj.result_obj}.select{|aqua_result|aqua_result.is_a?(AquaResult)}
		varcallids = ljs.map{|aqua_result| aqua_result.load}.flatten.uniq
		return nil if varcallids.size == 0
		"variation_calls.id NOT IN (#{varcallids.join(",")})"
	end
	
	def not_present_in_job_variant(values)
		ljs = LongJob.where(id: values)
		ljs = ljs.map{|lj| lj.result_obj}.select{|aqua_result|aqua_result.is_a?(AquaResult)}
		varcallids = ljs.map{|aqua_result| aqua_result.load}.flatten.uniq
		varids = VariationCall.where(id: varcallids).pluck(:variation_id).uniq
		return nil if varcallids.size == 0 or varids.size == 0
		Aqua.quick_not_in "variation_calls.variation_id", varids, "variations"
	end
	
	def list_jobs(params)
		experiment = Experiment.find(params[:experiment])
		ret = experiment.long_jobs.where(status: [LongJob::DONE, LongJob::STORED]).map{|lj|
			ljparam = YAML.load(lj.parameter).first
			ljparam = {"samples" => [], "queries" => {}} if ljparam.nil?
			{
				id: lj.id,
				title: lj.title,
				user: lj.user,
				size: lj.result_obj.size,
				samples: (ljparam["samples"] || [])[0..12].join(",").to_s + (((ljparam["samples"] || []).size > 12)?"...":""),
				num_samples: ljparam["samples"].size,
				parameters: ljparam["queries"].keys.map{|q|
					ljparam["queries"][q].map{|qname, qconf|
						next if qconf["value"].nil? or qconf["value"] == ""
						"#{q}:#{qname}=#{qconf["value"]}"
					}.reject(&:nil?)
				}.flatten.join(", ")
			}
		}
		ret
	end
	
end