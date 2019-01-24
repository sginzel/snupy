# == Description
# Helper Module
module VcfFilesHelper
	# this is used to
	def aqua_annotate_single()
		_invalidate_cache
		vcf_file = VcfFile.select(%w(id name status organism_id)).find(params[:id])
		statuses = vcf_file.aqua_status_annotations
		statuses.reject!{|st| st.tool.nil?}
		statuses = statuses.select{|st| (params[:ids] || params[:tools]).include?(st.tool.name)}
		#if (statuses.all?(&:is_pending?)) then
		if (1 == 1) then
			old_stat = vcf_file.status
			begin
				vcf_file.status = :INCOMPLETE # set vcf file status to incomplete before the annotation
				long_job = vcf_file.annotate((params[:ids] || params[:tools]), http_remote_user())
			rescue RuntimeError => e
				vcf_file.status = old_stat
				render text: "Starting the annotation failed #{e.message}"
				return
			end
			if long_job.nil?
				render text: "VCF is not in a state to be annotated. Set to Incomplete first."
				return
			else
				render text: "#{long_job.title} started for #{(params[:ids] || params[:tools])}. PLEASE REFRESH YOUR JOB LIST. "
				return
			end
		else
			render text: "#{vcf_file.name} is not pending for #{statuses.map{|t| "#{t.source}:#{t.value}"}.join(",")}."
		end

	end
end
