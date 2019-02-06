class SamplesController < ApplicationController
	include ApplicationHelper
	include SampleCreateFromSampleSheetHelper
	
	before_filter :admin_required, :only => [ :delete, :destroy ]
	before_filter :access_required
	# GET /samples
	# GET /samples.json
	
	def _invalidate_cache
		# expire_page :action => :index
		# expire_action :action => :index
		# invalidates all caches of samples for all users
		expire_fragment(/samples/)
	end
	
	def refreshindex
		_invalidate_cache
		redirect_to :samples
	end
	
	def index
		#if !(current_user.is_admin?) then
		#	@samples = Sample.joins(:users).where("users.name = ?", current_user.name)
		#else
		# 	@samples = Sample.all
		#end
		#@samples = current_user.visible(Sample)
		@my_samples = current_user.editable(Sample).pluck(:id)
		#smplids = Sample.joins(:vcf_file_nodata).where("vcf_files.institution_id" => current_user.institution_ids)
		#smplids = smplids.limit(params["count"]) unless params["count"].nil?
		#smplids = smplids.pluck("samples.id")
		#@samples = Sample.where(id: smplids)
		#			 .includes([:tags, :entity, :entity_group, :vcf_file_nodata, :experiments, :institution])
		@samples = current_user.visible(Sample)
					   .includes([:tags, :entity, :entity_group, :vcf_file_nodata, :experiments, :institution, :reports])
		
		@samples = @samples.where("samples.id" => params[:ids]) unless params[:ids].nil?
		@samples = filter_collection @samples, [:name, :patient, "vcf_files.name", :vcf_sample_name,
												:min_read_depth, :status, :ignorefilter, :filters, "tags.value"], 100
		
		
		# this only happens when the user tries to create a new sample and a request is made
		# to get the samples that are not yet processed
		if !params[:vcf_file_id].nil? then
			@samples.select!{|s| s.vcf_file_id == params[:vcf_file_id].to_i}
		end
		
		# @samples.sort!{|x,y| y.created_at <=> x.created_at}
		
		@stat_collectors = Sample.statistic_collectors().map{|c|{resource: c.name}}
		
		respond_to do |format|
			format.html # index.html.erb
			format.json { render json: @samples }
		end
	end
	
	def claimable
		claimable = {}
		if !params[:vcf_file_id].nil? then
			vcf = VcfFile.select([:id, :sample_names, :status, :filters]).find(params[:vcf_file_id])
			vcf_smpls_names = vcf.get_sample_names
			claimable = Hash[vcf_smpls_names.map{|smplname| [smplname, true] }]
			claimed_samples = Sample.where(vcf_file_id: vcf).where(vcf_sample_name: vcf_smpls_names).pluck(:vcf_sample_name)
			claimed_samples.each{|smplname| claimable[smplname] = false}
			claimable.reject!{|smplname, isclaimable| !isclaimable } if !current_user.is_admin
			claimable[:_filters] = YAML.load(vcf.filters)
		end
		
		respond_to do |format|
			format.json { render json: claimable }
		end
	end
	
	# GET /samples/1
	# GET /samples/1.json
	def show
		accessible_samples = current_user.visible(Sample).pluck("samples.id")
		if accessible_samples.include?(params[:id].to_i)
			@sample = Sample.find(params[:id])
			@stat_collectors = Sample.statistic_collectors().map{|c|{resource: c.name}}
			@missing_stat_collectors = @stat_collectors.reject{|sc|
				@sample.statistics.map{|ss| ss.resource}.map(&:to_s).include?(sc[:resource])
			}
			respond_to do |format|
				format.html # show.html.erb
				format.json { render json: @sample }
			end
		else
			alert_and_back_or_redirect("You have no access to this.")
			return
		end
	end
	
	# GET /samples/new
	# GET /samples/new.json
	# TODO Add Roles to VCFFile Access
	def new
		@sample = Sample.new
		# @vcf_files = VcfFile.all_without_data.reject{|s| s.status != :DONE}.sort{|v1, v2| v1.name <=> v2.name}
		@user = current_user
		if !@user.is_admin then
			@users = User.all
		else
			@users = @user.institutions.map(&:users).flatten.uniq
		end
		vcf_file_ids = :all
		if !@user.is_admin then
			vcf_file_ids = @user.institutions.map{|i| i.vcf_files.select([:id]).pluck(:id) }.flatten.uniq
		end
		# @vcf_files = VcfFile.nodata.find(vcf_file_ids).reject{|s| s.status != :DONE}
		@vcf_files = current_user.editable(VcfFile).nodata.order(:name)
		
		# @vcf_files = (@vcf_files || []).sort{|v1, v2| v1.name <=> v2.name}
		
		@added_vcf_files = find_processed_samples(@vcf_files)
		
		
		@selected_tags = {}
		@tags = Sample.available_tags true
		#@sample_tags = SampleTag.uniq(:tag_name).pluck(:tag_name).sort
		#@sample_tags = Hash[
		#	@sample_tags.map{|tn|
		#		[tn.to_s, SampleTag.where(tag_name: tn)]
		#	}
		#]
		## only admins may see vcf files and samples that were already processed/imported
		if !@user.is_admin
			@added_vcf_files.select!{|vcfid, smpls|
				smpls.size > 0
			}
		end
		
		if !params[:vcf_file_id].nil?
			@vcf_file = current_user.visible(VcfFile).find(params[:vcf_file_id], select: [:id, :sample_names, :name, :filters].map{|x| "vcf_files.#{x}"})
			if !@vcf_file.aqua_annotation_completed? then
				flash[:alert] = "VcfFile ##{params[:vcf_file_id]} not ready"
				@vcf_file = nil
			end
		else
			@vcf_file = nil
		end
		@specimen_probes = current_user.visible(SpecimenProbe)
		respond_to do |format|
			format.html # new.html.erb
			format.json { render json: @sample }
		end
	end
	
	# GET /samples/1/edit
	# TODO Add Roles to VCFFile Access
	def edit
		# @samples = current_user.editable(Sample)
		@sample = current_user.editable(Sample).find(params[:id])
		
		@user = current_user
		if @user.is_admin then
			@users = User.all
		else
			@users = @user.institutions.map(&:users).flatten.uniq
		end
		
		#vcf_file_ids = :all
		#if !@user.is_admin then
		#  vcf_file_ids = @user.institutions.map{|i| i.vcf_files.select([:id]).pluck(:id) }.flatten.uniq
		#end
		
		#@vcf_files = VcfFile.all_without_data(vcf_file_ids).reject{|s| s.status != :DONE}
		@vcf_files = current_user.editable(VcfFile).nodata.where(status: 'DONE').order(:name)
		# @vcf_files = VcfFile.nodata.find(vcf_file_ids).reject{|s| s.status != :DONE}
		# @vcf_files = (@vcf_files || []).sort{|v1, v2| v1.name <=> v2.name}
		@added_vcf_files = find_processed_samples(@vcf_files)
		## only admins may see vcf files and samples that were already processed/imported
		if !@user.is_admin
			@added_vcf_files.select!{|vcfid, smpls|
				smpls.size > 0
			}
		end
		
		@vcf_file = @sample.vcf_file
		
		if !@vcf_file.aqua_annotation_completed? then
			redirect_to action: :index, :flash => { :error => "VCF not ready" }
			return true
		end
		
		## TAGS
		@selected_tags = {}
		@sample.tags.each do |tag|
			@selected_tags[tag.category.to_s] = [] if @selected_tags[tag.category.to_s].nil?
			@selected_tags[tag.category.to_s] << tag
		end
		@tags = Sample.available_tags true
		@specimen_probes = current_user.visible(SpecimenProbe)
		#@status_tags = @sample.sample_tags.where(tag_name: "STATUS")
		#@tissue_tags = @sample.sample_tags.where(tag_name: "TISSUE")
		#@disease_tags = @sample.sample_tags.where(tag_name: "DISEASE")
		#@collegues = current_user.institutions.map(&:users).flatten.uniq
	end
	
	# POST /samples
	# POST /samples.json
	def create
		_invalidate_cache
		if !params[:sample][:sample_sheet].nil? then
			return create_from_sample_sheet
		end
		
		@sample = Sample.new(params[:sample])
		@vcf_file = VcfFile.nodata.where(id: @sample.vcf_file_id).first
		if @vcf_file.nil? or !@vcf_file.aqua_annotation_completed? then
			flash[:alert] = "VCF not ready(##{@sample.vcf_file_id})"
			redirect_to action: :index
			return true
		end
		
		@specimen = nil
		if not params[:specimen_probe_id].nil? then
			@specimen = SpecimenProbe.where(id: params[:specimen_probe_id]).first.id
		end
		@sample.specimen_probe_id = @specimen
		@users = (User.find_all_by_id(params[:users]) || [])
		@user = current_user
		@sample.users = (@users + [@user]).uniq
		
		tagids = (params[:tags] || {}).values.flatten.uniq
		# @tags = (Tag.find_all_by_id(tagids || []).map{|name, ids| ids}.flatten)
		@sample.tags = Tag.where(id: tagids)
		
		#@status_tags = SampleTag.find_all_by_id(params[:status_tag]) 
		#@tissue_tags = SampleTag.find_all_by_id(params[:tissue_tag]) 
		#@disease_tags = SampleTag.find_all_by_id(params[:disease_tag])
		
		@sample.filters = @sample.filters.join(",") if @sample.filters.is_a?(Array)
		# let us make sure we use all filters if ignorefilter option is set - disregarding the user input.
		@sample.filters = YAML.load(VcfFile.select([:id, :filters]).find(@sample.vcf_file_id).filters).keys.sort.join(",") if @sample.ignorefilter
		
		# result = @sample.add_variation_calls
		result = nil
		respond_to do |format|
			if @sample.save
				# @sample.sample_tags = [@status_tags, @tissue_tags, @disease_tags].flatten
				notice = "Sample created, variation calls will be available soon"
				if !@sample.vcf_file_id.nil? and !@sample.vcf_sample_name.nil? then
					@sample.status = "ENQUEUED"
					@sample.save!
					@long_job = LongJob.create_job({
													   title: "Extract #{@sample.name}",
													   handle: @sample,
													   method: :add_variation_calls,
													   user: http_remote_user(),
													   queue: "annotation"
												   }, false)
				else
					notice = "Sample created, no VcfFile selected"
				end
				# flash[:notice] = "Could not add variation calls."
				format.html { redirect_to @sample, notice: notice }
				# format.json { render json: @sample, status: :created, location: @sample }
			else
				format.html { render action: "new" }
				# format.json { render json: @sample.errors, status: :unprocessable_entity }
			end
		end
	end
	
	
	
	# PUT /samples/1
	# PUT /samples/1.json
	def update
		# @sample = Sample.find(params[:id])
		@sample = current_user.editable(Sample).find(params[:id], readonly: false)
		_invalidate_cache
		# we dont really need @vcf_files here do we?
		#@vcf_files = VcfFile.all_without_data.sort{|v1, v2| v1.name <=> v2.name}
		#@added_vcf_files = find_processed_samples(@vcf_files)
		### only admins may see vcf files and samples that were already processed/imported
		#@user = current_user
		#if !@user.is_admin
		#	@added_vcf_files.select!{|vcfid, smpls|
		#		smpls.size > 0
		#	}
		#end
		
		@vcf_file = @sample.vcf_file
		@users = User.all
		
		@tags = Tag.find_all_by_id((params[:tags] || []).map{|name, ids| ids}.flatten)
		# @status_tags = SampleTag.find_all_by_id(params[:status_tag]) 
		# @tissue_tags = SampleTag.find_all_by_id(params[:tissue_tag]) 
		# @disease_tags = SampleTag.find_all_by_id(params[:disease_tag])
		# @users = User.find_all_by_name(params[:users])
		
		respond_to do |format|
			vcf_file_id_before = @sample.vcf_file_id
			vcf_sample_name_before = @sample.vcf_sample_name
			ignore_filter_before = @sample.ignorefilter
			min_read_depth_before = @sample.min_read_depth
			info_matches_before = @sample.info_matches
			filters_before = @sample.filters
			params[:sample][:filters] = params[:sample][:filters].join(",") if params[:sample][:filters].is_a?(Array)
			@sample.tags = @tags
			if @sample.update_attributes(params[:sample])
				@sample.users = User.find_all_by_id(params[:users])
				@sample.updating_vcf_file = @sample.vcf_file_id_changed?
				# @sample.sample_tags = [@status_tags, @tissue_tags, @disease_tags].flatten
				# make sure that filters is set consistently with the ignorefilteroption
				@sample.filters = YAML.load(VcfFile.select([:id, :filters]).find(@sample.vcf_file_id).filters).keys.sort.join(",") if @sample.ignorefilter
				notice = 'Sample was successfully updated'
				if @sample.vcf_file_id != vcf_file_id_before or
					@sample.vcf_sample_name != vcf_sample_name_before or
					@sample.ignorefilter != ignore_filter_before or
					@sample.min_read_depth != min_read_depth_before or
					@sample.info_matches.to_s != info_matches_before.to_s or
					@sample.filters.to_s != filters_before.to_s or
					(params[:force_reload] == "1" and !@sample.vcf_file_id.nil? and !@sample.vcf_sample_name.nil?) then
					@sample.status = "ENQUEUED"
					@sample.save!
					@long_job = LongJob.create_job({
													   title: "Updating variation calls for #{@sample.name}",
													   handle: @sample,
													   method: :add_variation_calls,
													   user: http_remote_user(),
													   queue: "annotation"
												   }, false)
					notice << " and variation calls are updated because"
					notice << ", the vcf file changed" if @sample.vcf_file_id != vcf_file_id_before
					notice << ", the vcf sample name changed" if @sample.vcf_sample_name != vcf_sample_name_before
					notice << ", the ignorefilter option changed" if @sample.ignorefilter != ignore_filter_before
					notice << ", the selected filters changed" if @sample.filters.to_s != filters_before.to_s
					notice << ", the minimum read depth changed" if @sample.min_read_depth != min_read_depth_before
					notice << ", the info matches field changed" if @sample.info_matches != info_matches_before
					notice << ", a reload was forced" if (params[:force_reload] == "1" and !@sample.vcf_file_id.nil? and !@sample.vcf_sample_name.nil?)
				end
				format.html { redirect_to @sample, notice: notice }
				# format.json { head :no_content }
			else
				format.html { render action: "edit" }
			end
		end
	end
	
	# DELETE /samples/1
	# DELETE /samples/1.json
	def destroy
		_invalidate_cache
		@sample = Sample.find(params[:id])
		@sample.tags = []
		@sample.destroy
		respond_to do |format|
			format.html { redirect_to samples_url }
			format.json { head :no_content }
		end
	end
	
	def force_reload()
		return false unless current_user.is_admin?
		if !params[:ids].nil?
			require_params = {
				ids: params[:ids],
				confirm: [["No", "no"], ["Yes", "yes"]]
				# format: [["HTML", "html"], ["GRAPHML", "graphml"]]
			}
			if determine_missing_params(require_params).size > 0 then
				render_table_details_params(require_params, label: "Please confirm your selection to reload #{params[:ids].size} samples. All current data will be lost.")
			else
				if params[:confirm] == "yes" then
					smplids = params[:ids]
					smpls = Sample.where(id: smplids)
					Sample.where(id: smplids).each do |sample|
						sample.status = "ENQUEUED"
						sample.save!
						long_job = LongJob.create_job({
														  title: "Force reload of #{sample.name}",
														  handle: sample,
														  method: :add_variation_calls,
														  user: http_remote_user(),
														  queue: "annotation"
													  }, false)
					end
					_invalidate_cache # cache needs to be invalidated, because the status changed
					render text: "#{smpls.size} samples are being refreshed. Please reload the samples index page."
				else
					render text: "Aborted."
				end
			end
		else
			render text: "No entries selected"
		end
	end
	
	def mass_destroy()
		return false unless current_user.is_admin?
		if !params[:ids].nil?
			require_params = {
				ids: params[:ids],
				confirm: [["No - please have mercy", "no"], ["Destroy selected samples", "yes"]]
				# format: [["HTML", "html"], ["GRAPHML", "graphml"]]
			}
			if determine_missing_params(require_params).size > 0 then
				render_table_details_params(require_params, label: "Please confirm your selection to destroy #{params[:ids].size} samples. All data will be lost and the action will be logged.")
			else
				if params[:confirm] == "yes" then
					smpls = EventLog.record do |eventlog|
						smplids = params[:ids]
						smpls = Sample.where(id: smplids)
						smpls = Sample.where(id: smplids).destroy_all
						eventlog.data = smpls.map(&:attributes).to_yaml
						eventlog.category = "Sample#destroy"
						_invalidate_cache # cache needs to be invalidated, because the status changed
						smpls
					end
					render text: "#{smpls.size} samples were destroyed. Please reload the samples index page."
				else
					render text: "Aborted."
				end
			end
		else
			render text: "No entries selected"
		end
		# return true # smplids.to_json
	end
	
	def sample_similarity()
		if params[:ids].nil? or params[:ids].size > 10 or params[:ids].size < 2 then
			render text: "Please select two to ten samples."
			return false
		end
		require_params = {
			ids: params[:ids],
			measurement: [["relative overlap", "relative"], ["absolute overlap", "absolute"], ["cosine similarity", "cosine"], ["weighted cosine similarity", "cosine_weighted"]],
			read_depth: "20"
			# format: [["HTML", "html"], ["GRAPHML", "graphml"]]
		}
		if determine_missing_params(require_params).size > 0 then
			render_table_details_params(require_params, label: "How should the similarity be calculated? Select 2-10 samples.")
			return true
		else
			min = (10**10).to_f
			max = -(10**10).to_f
			smpls = Sample.where(id: params[:ids]).order(:name)
			cache = {}
			table = smpls.map{|smpl1|
				matrow = {}
				matrow[:name] = "#{smpl1.name} (#{smpl1.nickname})"
				smpls.each do |smpl2|
					k = [smpl1.name, smpl2.name].sort
					if cache[k].nil?
						sim = smpl1.overlap(smpl2, params[:measurement].to_sym, params[:read_depth].to_i).round(3)
						max = [sim, max].max unless sim.nan? or sim.nil?
						min = [sim, min].min unless sim.nan? or sim.nil?
						cache[k] = sim
					
					end
					matrow[smpl2.nickname] = cache[k]
				end
				matrow
			}
		end
		smpls = nil
		
		render partial: "samples/similarity", locals: {simmat: table, min: min, max: max, measure: params[:measurement]}
	end
	
	def assign_specimen
		if params[:ids].nil? or params[:ids].size > 20 then
			render text: "Please select 1-20 samples."
			return false
		end
		
		smpls = Sample.where(id: params[:ids]).includes(:organism)
		organism_id = smpls.map(&:organism).map(&:id).uniq
		
		if organism_id.size != 1 then
			render text: "Samples have different organisms."
			return false
		else
			organism_id = organism_id.first
		end
		
		if !params[:entity_group]
			entity_groups = current_user.visible(EntityGroup).where(organism_id: organism_id).map{|eg| [eg.name, eg.id]}
			require_params = {
				ids: params[:ids],
				entity_group: entity_groups
			}
			if determine_missing_params(require_params).size > 0 then
				render_table_details_params(require_params, label: "Select a Entity Group ")
				return true
			end
		end
		
		entity_group = EntityGroup.find(params[:entity_group])
		specimens = current_user.visible(SpecimenProbe).where(entity_id: entity_group.entities)
		specimens.map!{|sp| [sp.name, sp.id]}
		# sort specimens according to their similarity of the name of the selected samples
		# we just count overlapping characters for this one. Should be enough
		smpl_name_msk = Sample.where(id: params[:ids]).map(&:name).join("").split(//).uniq
		specimens = specimens.sort{|x,y|
			x1 = (x.first.split(//).uniq & smpl_name_msk).size
			y1 = (y.first.split(//).uniq & smpl_name_msk).size
			if x1 > 0 && y1 > 0 then
				ret = y1 <=> x1
			elsif x1 == 0 && y1 > 0 then
				ret = 1
			elsif x1 > 0 && y1 == 0 then
				ret = -1
			end
			ret = x.first <=> y.first if ret == 0
			ret
		}
		require_params = {
			ids: params[:ids],
			specimen: [["seperate samples from specimen", "unlink"]] + specimens,
			entity_group: params[:entity_group]
		}
		if determine_missing_params(require_params).size > 0 then
			render_table_details_params(require_params, label: "Assign specimen to #{params[:ids].size} samples. ")
			return true
		else
			if params[:specimen] != "unlink" then
				specimen = SpecimenProbe.find(params[:specimen])
			else
				specimen = nil
			end
			success = false
			num_changes = nil
			Sample.transaction do
				num_changes = Sample.where(id: params[:ids]).update_all(specimen_probe_id: specimen)
				success = num_changes == params[:ids].size
				raise ActiveRecord::Rollback if !success
			end
			if success then
				render text: "#{num_changes} samples #{(specimen.nil?)?"seperated":"assigned to #{specimen.to_s}"}"
			else
				render text: "[ERROR] samples were not updated."
			end
		
		end
	end
	
	def gender_coefficient
		if params[:ids].nil? or params[:ids].size > 20 then
			render text: "Please select 1-20 samples."
			return false
		end
		samples = Sample.find(params[:ids])
		table = samples.map{|smpl|
			gender_stats = smpl.sample_statistics.select{|x| x.resource == SnupyAgain::StatisticCollector::SampleGenderCollector.to_s }
			if gender_stats.nil? or gender_stats.size == 0 then
				smpl.refresh_statistics([SnupyAgain::StatisticCollector::SampleGenderCollector])
				smpl.reload
				gender_stats = smpl.sample_statistics.select{|x| x.resource == SnupyAgain::StatisticCollector::SampleGenderCollector.to_s }
			end
			if !gender_stats.first.nil?
				gender_coeff = (YAML.load(gender_stats.first.value).first || {})
			else
				gender_coeff = {}
			end
			{
				name: smpl.name,
				nickname: smpl.nickname,
				gender_coeffcient: gender_coeff[:coeff].to_f,
				gender_prediction: gender_coeff[:gender_prediction].to_s
			}
		}
		smpls = nil
		
		render partial: "home/table", locals: {content: table, tableid: "gender_coeffiecient#{Time.now.to_i}", table_class: "snupytable"}
	end

	# refreshes statistics for selected samples
	def refresh_stats
		if (params[:ids] || []).size > 0 then
			cnt = 1
			slices = params[:ids].each_slice(250)
			slices.each do |ids|
				@long_job = LongJob.create_job({
																					 title: "Refreshing statistics for #{params[:ids].size} samples (#{cnt}/#{slices.size})",
																					 handle: Sample,
																					 method: :refresh_statistics,
																					 user: http_remote_user(),
																					 queue: "snupy",
																					 result_view: samples_path(ids: ids)
																			 }, false, params[:ids])
				cnt += 1
			end
			render text: "Queued a job to refresh the selected samples."
		else
			render text: "Please select at least one sample"
		end
	end
	
	def detail
		@sample = Sample.find(params[:id])
		@stat_collectors = Sample.statistic_collectors().map{|c|{resource: c.name}}
		@missing_stat_collectors = @stat_collectors.reject{|sc|
			@sample.statistics.map{|ss| ss.resource}.map(&:to_s).include?(sc[:resource])
		}
		respond_to do |format|
			format.html { render action: "show",layout: false }
			format.json { render json: @sample, status: :details, location: @sample }
		end
	end
	
	def collectstats
		@sample = Sample.find(params[:id])
		@resource = params[:resource]
		available = SnupyAgain::StatisticCollector::Template.collectors(nil).map{|c| c.name}
		if available.include?(@resource)
			@collector = eval(@resource).new(@sample)
			@long_job = LongJob.create_job({
											   title: "Collecting statistics from #{@resource} of #{@sample.nickname}",
											   handle: @collector,
											   method: :collect,
											   user: http_remote_user(),
											   queue: "snupy",
											   result_view: sample_path(@sample)
										   }, false, true)
			respond_to do |format|
				format.js { render partial: "collectstats"}
			end
		else
			render :status => 500
		end
	end

	# refreshes statistics for all samples
	def refreshstats
		_invalidate_cache
		if !current_user.is_admin? then
			render :status => 500
			return
		end
		@resource = params[:resource]
		if !@resource.nil?
			@samples = Sample.pluck(:id) # this disregards the users priviledges
			available = SnupyAgain::StatisticCollector::Template.collectors(nil).map{|c| c.name}
			if available.include?(@resource)
				@collector = eval(@resource)
				cnt = 1
				@long_jobs = []
				slices = @samples.each_slice(250)
				slices.each do |ids|
					@long_jobs << LongJob.create_job({
																							 title: "Refresh #{@resource} ##{@samples.size} samples (#{cnt}/#{slices.size})",
																							 handle: @collector,
																							 method: :batchrefresh,
																							 user: http_remote_user(),
																							 queue: "snupy"
																					 }, false, Sample, ids, true)
					cnt += 1
				end

				respond_to do |format|
					format.js { render partial: "collectstats"}
				end
			else
				render :status => 500
			end
		else
			render :status => 500
		end
	end
	
	private
	def find_processed_samples(vcf_files = nil)
		## find vcf files that were already imported
		@added_vcf_files = Hash[(@vcf_files || vcf_files).map{|vcf| [vcf.id, vcf.get_sample_names()]}]
		smpls = Sample.select([:vcf_file_id, :vcf_sample_name]).map{|s|[s.vcf_file_id, s.vcf_sample_name]}.uniq
		smpls.each do |vcfid, smplname|
			next if @added_vcf_files[vcfid].nil?
			@added_vcf_files[vcfid].delete(smplname)
		end
		return @added_vcf_files
	end
end
