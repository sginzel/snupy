class VcfFilesController < ApplicationController
	include ApplicationHelper
	include SampleCreateFromSampleSheetHelper
	include VcfFilesHelper
	# before_filter :admin_required, :only => [ :new, :index, :edit, :create, :delete, :destroy, :update ]
	before_filter :access_required
	
	def _invalidate_cache
		# expire_page :action => :index
		# expire_action :action => :index
		# invalidates all caches of samples for all users
		expire_fragment(/vcf_files/)
	end
	
	def refreshindex
		_invalidate_cache
		redirect_to :vcf_files
	end
	
	# GET /vcf_files
	# GET /vcf_files.json
	def index
		# @vcf_files = VcfFile.all_without_data.sort{|x,y| y.updated_at <=> x.updated_at}
		# @vcf_files = [] unless current_user.is_admin
		@vcf_files = current_user.visible(VcfFile).nodata #.select([:created_at, :updated_at]).order("updated_at DESC")
		@vcf_files = @vcf_files.where("vcf_files.id" => params[:ids]) unless params[:ids].nil?
		@vcf_files = filter_collection @vcf_files, [:name, :filename, :sample_names, :status, :organism_id, :contact, :id, :institution_id], 100
		@vcf_files = @vcf_files.includes([:tags, :samples, :aqua_status_annotations, :reports])
		@vcf_files.map!{|vcf|vcf.becomes(VcfFile)}
		
		
		respond_to do |format|
			format.html # index.html.erb
			format.json {render json: @vcf_files,
			                    :include => {
									samples: {:only => [:id, :status, :name, :vcf_file_id, :vcf_sample_name, :specimen_probe_id, :entity_id, :entity_group_id],
									          :except => [:created_at, :updated_at]}
			                    }
			}
		end
	end
	
	# GET /vcf_files/1
	# GET /vcf_files/1.json
	def show
		if (params[:content] || 0).to_i == 1 then
			@vcf_file = VcfFile.find(params[:id])
		else
			# attr = VcfFile.attribute_names.reject{|n| n == "content"}
			# @vcf_file = VcfFile.find(params[:id], select: attr)
			@vcf_file = VcfFile.nodata.find(params[:id])
		end
		
		respond_to do |format|
			format.html # show.html.erb
			format.json {
				# render json: @vcf_file
				render :partial => "vcf_files/vcf_file.json", locals: {vcf_file: @vcf_file}
			}
		end
	end
	
	# GET /vcf_files/new
	# GET /vcf_files/new.json
	def new
		redirect_to action: "batch_submit"
		return true if 1 == 1
		@vcf_file = VcfFile.new
		respond_to do |format|
			format.html # new.html.erb
			# format.json { render json: @vcf_file }
		end
	end
	
	# GET /vcf_files/1/edit
	def edit
		@vcf_file = current_user.editable(VcfFile).find(params[:id])
		# @vcf_file = VcfFile.find(params[:id])
	end
	
	def vcf_file_template
		institutions              = Institution.all
		vcf_types                 = ([VcfFile] + VcfFile.descendants).map {|klass| [klass.name, klass.name]}
		organisms                 = Organism.all
		tags                      = VcfFile.available_tags_by_category
		@vcf_template             = {
			"content"        => {type: :file, onchange: "updateVcfName(this);"},
			"name"           => {type: :string, placeholder: "required", size: 64},
			"contact"        => {type: :string, placeholder: "optional"},
			"institution_id" => {type: :combobox, options: institutions.map {|i| [i.name, i.id]}, validonly: true},
			"md5checksum"    => {type: :string, placeholder: "optional"},
			"type"           => {type: :combobox, options: vcf_types, validonly: true, selected: "VcfFile"},
			"organism_id"    => {type: :combobox, options: organisms.map {|o| [o.name, o.id]}, validonly: true, include_blank: true}
		}
		@vcf_attribute_to_colname = {
			"content"        => "File",
			"name"           => "Name",
			"contact"        => "Contact",
			"institution_id" => "Institution",
			"md5checksum"    => "MD5 checksum",
			"type"           => "Parser",
			"organism_id"    => "Organism"
		}
		(tags.keys).sort.each do |category|
			@vcf_template["tags[#{category}]"]             = {type: :combobox, options: tags[category].map {|tag| [tag.value, tag.id]}, validonly: true}
			@vcf_attribute_to_colname["tags[#{category}]"] = "tags[#{category}]"
		end
	end
	
	def batch_submit
		vcf_file_template()
		@vcf_files        = []
		@errornous_vcfs   = []
		@number_of_field  = (params[:number] || 16).to_i
		invalidated_cache = false
		#if (1==0)
		(params[:vcf_file_templates] || {}).each do |i, vcf_file|
			# vcf_file = (vcf_file_template[:vcf_file] || {})
			# (params[:vcf_file] || []).each do |vcf_file|
			next if (vcf_file["content"] || vcf_file[:content]).nil?
			next if vcf_file["name"] == "" && !(vcf_file["content"] || vcf_file[:content]).original_filename.index(/.zip$/)
			_invalidate_cache unless invalidated_cache
			invalidated_cache = true
			d "creating VCfFile #{vcf_file[:name]}"
			# create_vcf_file can create and array of vcf files if the upload is an archive
			# results = VcfFile.create_vcf_file(vcf_file)
			# results = VcfFile.create_vcf_file_from_upload(vcf_file) do |result|
			VcfFile.create_vcf_file_from_upload(vcf_file) do |results|
				results = [results] unless results.is_a?(Array)
				results.each do |result|
					if result[:created] then
						if result[:vcf_file].save
							# initilize aqua annotation status
							result[:vcf_file].aqua_annotation_status
							result[:vcf_file].predict_tags_by_name
							# result[:vcf_file].import_variants(http_remote_user())
							# we load the vcf attributes from the database again - this time without the content
							#@vcf_files << VcfFile.find_without_data(result[:vcf_file].id) # result[:vcf_file]
							@vcf_files << VcfFile.where(id: result[:vcf_file].id).nodata.includes([:tags, :aqua_status_annotations]).first # result[:vcf_file]
						else
							result[:alert] = "Could not safe record"
							@errornous_vcfs << {input: vcf_file, output: result}
						end
					else
						@errornous_vcfs << {input: vcf_file, output: result}
					end
				end
			end
		end

		#end # remove me
		#respond_to do |format|
		#	format.html # new.html.erb
		#end
	end
	
	def create_sample_sheet
		if (params[:ids].nil?)
			render text: "Please select VCF files from the list."
			return true
		end
		@user          = current_user
		require_params = {
			ids:     params[:ids],
			user:    User.all.map {|u| [u.name, u.id]}.sort {|a1, a2|
				if (a1[1] == @user.id)
					-1
				elsif (a2[1] == @user.id)
					1
				else
					a1[0] <=> a2[0]
				end
			},
			project: [" ", " "] + current_user.visible(Experiment).where("experiments.id > 0").order("name ASC, title ASC").map {|u| [(u.name || u.title), u.id]}
			# disease: SampleTag.where(tag_name: "DISEASE").sort.map{|st| [st.tag_value, st.id]},
			# tissue: SampleTag.where(tag_name: "TISSUE").sort.map{|st| [st.tag_value, st.id]},
			#status: SampleTag.where(tag_name: "STATUS").sort.map{|st| [st.tag_value, st.id]}
		}
		Sample.available_tags(true).each do |category, tags|
			require_params["tags[" + category + "]"] = tags.map {|st| [st.value, st.id]}
		end
		# SampleTag.tag_name_category.each{|tag_name, tags|
		#	require_params["sample_tags[" + tag_name + "]"] = tags.map{|st| [st.tag_value, st.id]}
		#}
		
		if determine_missing_params(require_params).size > 0 then
			render_table_details_params(require_params)
		else
			# @vcf_files = VcfFile.all_without_data(params[:ids]).select{|vcf| vcf.status == :DONE}
			# @vcf_files   = VcfFile.nodata.find(params[:ids]).select {|vcf| vcf.status == :DONE}
			@vcf_files   = VcfFile.nodata.find(params[:ids]).reject {|vcf| vcf.vcf_file_index.nil?}
			@default_tag = params[:tags].map {|category, tagid|
				[category, Tag.find(tagid)]
			}
			
			@default_user = User.find(params[:user])
			if params[:project] != " " then
				@project = Experiment.find(params[:project])
			else
				@project = Experiment.new()
			end
			
			@projects        = current_user.visible(Experiment).where("experiments.id > 0").order("name ASC, title ASC")
			@specimen_probes = @project.specimen_probes.includes(:entity)
			
			usernames = @project.users.includes(:institutions).select {|u| u.institution_ids.include?(@project.institution_id)}.map(&:name)
			usernames = [@default_user.name] + usernames
			
			#all_tags = SampleTag.where(tag_name: "STATUS")
			#all_states = [""]
			#all_disease_classes = [""]
			#all_tissue_origins = [""]
			#all_sample_types = [""]
			#all_tags.each do |tag|
			#	state, disease_class, tissue_origin, sample_type = tag.tag_value.scan(/[\[.*\]] - (.*)/).flatten.first.split(",",4)
			#	all_states << state.to_s
			#	all_disease_classes << disease_class.to_s
			#	all_tissue_origins << tissue_origin.to_s
			#	all_sample_types << sample_type.to_s
			#end
			#all_states = all_states.sort.uniq.map{|x| [x,x]}
			#all_disease_classes = all_disease_classes.sort.uniq.map{|x| [x,x]}
			#all_tissue_origins = all_tissue_origins.sort.uniq.map{|x| [x,x]}
			#all_sample_types = all_sample_types.sort.uniq.map{|x| [x,x]}
			#state, disease_class, tissue_origin, sample_type = @default_status.tag_value.scan(/[\[.*\]] - (.*)/).flatten.first.split(",",4)
			
			# ActionController::Base.helpers.link_to(symbol, "http://www.genecards.org/cgi-bin/carddisp.pl?gene=#{symbol}")
			@vcf_samples = @vcf_files.map {|vcf|
				smpl_names  = vcf.sample_names
				all_filters = YAML.load(vcf.filters).keys.sort.join(",")
				vcfname     = rename_sample(vcf.name)
				smpl_names.map do |sname|
					predicted_sample_name = rename_sample(sname.to_s)
					if sname == "TUMOR" then
						predicted_sample_name = (vcfname.split("/")[-1].to_s.split("-") || []).first
					elsif sname == "NORMAL" then
						predicted_sample_name = (vcfname.split("/")[-1].to_s.split("-") || [])[1]
					end
					predicted_sample_name = sname if predicted_sample_name.to_s == ""
					patient               = predicted_sample_name.gsub(/[a-z]/, "").gsub(/[_]+$/, "")
					# TODO Maybe we can implement a specimen probe suggestion somehow. But its really tricky.
					specimen_probe_suggestion = " "
					
					ret = {
						id:              "#{vcf.id}/#{sname}",
						vcf:             "#{vcf.name}" + (ActionController::Base.helpers.hidden_field_tag 'samples[]vcf_file_id', vcf.id),
						vcf_sample_name: "#{sname}" + (ActionController::Base.helpers.hidden_field_tag 'samples[]vcf_sample_name', sname)
					}
					# tbindex = 15
					tbindex = 0
					@default_tag.each do |category, tag|
						ret[category] = (ActionController::Base.helpers.select_tag "samples[]tags[#{tag.category}]", ActionController::Base.helpers.options_from_collection_for_select(Tag.where(category: tag.category).sort, "value", "value", tag.value), tabindex: tbindex)
						tbindex       += 1
					end
					ret = ret.merge({
						                name:           (ActionController::Base.helpers.text_field_tag 'samples[]name', "#{vcfname}/#{predicted_sample_name}", size: 57, tabindex: tbindex + 1),
						                nickname:       (ActionController::Base.helpers.text_field_tag 'samples[]nickname', "#{predicted_sample_name.gsub(" ", "_")}", size: 12, tabindex: tbindex + 2),
						                patient:        (ActionController::Base.helpers.text_field_tag 'samples[]patient', patient, size: 8, tabindex: tbindex + 3),
						                min_read_depth: (ActionController::Base.helpers.text_field_tag 'samples[]min_read_depth', "5", size: 4, tabindex: tbindex + 5),
						                project:        (ActionController::Base.helpers.select_tag "samples[]project", ActionController::Base.helpers.options_for_select([["", " "]] + @projects.map {|p| [p.name, p.id]}, @project.id), tabindex: tbindex + 6),
						                specimen:       (ActionController::Base.helpers.select_tag "samples[]specimen_probe_id", ActionController::Base.helpers.options_for_select([["", " "]] + @specimen_probes.map {|sp| ["#{(sp.entity || Entity.new).name}/#{sp.name}", sp.id]}.sort {|a, b| a.first <=> b.first}, specimen_probe_suggestion), tabindex: tbindex + 7),
						                # contact: (ActionController::Base.helpers.text_field_tag 'samples[]contact', (@project.contact || @default_user.full_name), tabindex: 6),
						                # gender: (ActionController::Base.helpers.select_tag "samples[]gender", ActionController::Base.helpers.options_for_select([["Unknown", "unknown"], ["Male", "male"], ["Female", "female"]], "unknown"), tabindex: 7),
						                contact: (ActionController::Base.helpers.text_field_tag 'samples[]contact', @default_user.full_name, tabindex: tbindex + 8),
						                #user: (ActionController::Base.helpers.select_tag 'samples[]users', ActionController::Base.helpers.options_from_collection_for_select(User.all.sort, "name", "name", @default_user.name), tabindex: 11),
						                user:         (ActionController::Base.helpers.text_field_tag 'samples[]users', (usernames).sort.uniq.join(";"), tabindex: tbindex + 11),
						                ignorefilter: (ActionController::Base.helpers.select_tag "samples[]ignorefilter", ActionController::Base.helpers.options_for_select([["User defined filters", "0"], ["Ignore filter", "1"], ["PASS ONLY", "2"]], "2"), tabindex: tbindex + 12),
						                filters:      (ActionController::Base.helpers.text_field_tag 'samples[]filters', all_filters, tabindex: tbindex + 13),
						                info_matches: (ActionController::Base.helpers.text_field_tag 'samples[]info_matches', "", size: 8, tabindex: tbindex + 14)
					                })
					
					ret
				end
			}.flatten
			
			respond_to do |format|
				format.html {
					render partial: "vcf_files/create_sample_sheet"
				}
			end
		end
	end
	
	def download_sample_sheet
		data = get_sample_sheet_tsv_data(params)
		if (params[:commit] == "Download Sheet") then
			respond_to do |format|
				format.all {
					send_data(data.join("\n"),
					          filename: "SampleExtractionSheet.csv",
					          type:     "text/plain")
				}
			end
			return true
		elsif params[:commit] == "Start Extraction" then
			params[:sample] = {
				sample_sheet: data
			}
			return create_from_sample_sheet
		end
	end
	
	def download
		@vcf_file = current_user.visible(VcfFile).find(params[:id])
		respond_to do |format|
			format.all {
				send_data(@vcf_file.unzipped_content,
				          filename:    "#{@vcf_file.name}.vcf",
				          type:        "text/plain",
				          disposition: "inline")
			}
		end
	end
	
	def assign_tags
		
		if !params[:tools]
			tools          = VcfFile.available_tags_by_category["TOOL"].map {|t| [t.value, t.id]}
			tools          = [["Remove all tags", "remove"]] + tools
			require_params = {
				ids:   params[:ids],
				tools: tools
			}
			if determine_missing_params(require_params).size > 0 then
				render_table_details_params(require_params, label: "Select a Tool tag to apply")
				return true
			end
		end
		vcf_files = VcfFile.nodata.where(id: params[:ids])
		if params[:tools] == "remove" then
			tool_tags = :remove
		else
			tool_tags = Tag.where(id: params[:tools]).first
		end
		if !tool_tags.nil? then
			vcf_files.each do |vcf_file|
				if tool_tags == :remove then
					vcf_file.tags = []
				else
					vcf_file.tags = [tool_tags]
				end
				vcf_file.save
			end
			if tool_tags == :remove then
				render text: "Tool tags removed from #{vcf_files.size} VcfFiles"
			else
				render text: "#{tool_tags.value} tool tags applied to #{vcf_files.size} VcfFiles"
			end
		
		else
			remder text: "Not all tools were found. #{params.pretty_inspect}"
		end
	
	
	end
	
	# Create a VcfFile object through a POST. 
	# This method checks the integrity of the file, by comparing the transfered file and
	# the provided MD5 checksum. It also compresses the content of the file and stores
	# it in the database for later processing. It also stores the sample names that
	# are present in the file so we can use them later.
	# POST /vcf_files
	# POST /vcf_files.json
	def create
		redirect_to action: "batch_submit", notice: 'Please use the batch submission to create a new VCF File'
		return
		_invalidate_cache()
		#result = VcfFile.create_vcf_file(params["vcf_file"])
		result = VcfFile.create_vcf_file_from_upload(params["vcf_file"]).first
		if !result[:created] then
			flash[:alert]  = result[:alert] unless result[:alert].nil?
			flash[:notice] = result[:notice] unless result[:notice].nil?
			if !result[:vcf_file].nil? then
				redirect_to vcf_file_url(result[:vcf_file]), notice: result[:notice].to_s, alert: result[:alert].to_s
			else
				respond_to do |format|
					format.html {redirect_to action: "new"}
				end
			end
		else
			@vcf_file = result[:vcf_file]
			
			respond_to do |format|
				if @vcf_file.save
					format.html {redirect_to @vcf_file, notice: 'Vcf file was successfully created.'}
					format.json {render json: @vcf_file, status: :created, location: @vcf_file}
				else
					format.html {render action: "new"}
					format.json {render json: @vcf_file.errors, status: :unprocessable_entity}
				end
			end
		end
	
	end
	
	# PUT /vcf_files/1
	# PUT /vcf_files/1.json
	def update
		@vcf_file = current_user.editable(VcfFile).find(params[:id], readonly: false).id
		# we have to make the file non-read_only
		@vcf_file = VcfFile.find(@vcf_file)
		
		_invalidate_cache
#		redirect_to vcf_file_url(@vcf_file), notice: 'Vcf files cannot be updated. Please delete this file and reupload it.'
#		return
		respond_to do |format|
			if @vcf_file.update_attributes(params[@vcf_file.type.underscore.to_sym]) ## this is neccessary because of the redirects that inherited models use
				@vcf_file.updating_content = @vcf_file.content_changed?
				format.html {redirect_to @vcf_file, notice: 'Vcf file was successfully updated.'}
#        format.json { head :no_content }
			else
				format.html {render action: "edit"}
#        format.json { render json: @vcf_file.errors, status: :unprocessable_entity }
			end
		end
	end
	
	# DELETE /vcf_files/1
	# DELETE /vcf_files/1.json
	def destroy
		if current_user.is_admin? then
			@vcf_file = current_user.editable(VcfFile).find(params[:id], readonly: false)
			@vcf_file.destroy
			_invalidate_cache()
		end
		respond_to do |format|
			format.html {redirect_to vcf_files_url}
			format.json {head :no_content}
		end
	end

	def mass_destroy
		return false unless current_user.is_admin?
		if !params[:ids].nil?
			require_params = {
					ids: params[:ids],
					confirm: [["No - please have mercy", "no"], ["Destroy selected samples", "yes"]]
					# format: [["HTML", "html"], ["GRAPHML", "graphml"]]
			}
			if determine_missing_params(require_params).size > 0 then
				render_table_details_params(require_params, label: "Please confirm your selection to destroy #{params[:ids].size} VCF files and the corresponding samples. All data will be lost and the action will be logged.")
			else
				if params[:confirm] == "yes" then
					vcfids = EventLog.record do |eventlog|
						vcfids = params[:ids]
						vcfids = VcfFile.where(id: vcfids).select([:id, :name, :filename, :sample_names, :status, :created_at, :updated_at, :organism_id, :md5checksum, :institution_id, :type]).destroy_all
						eventlog.data = vcfids.map(&:attributes).to_yaml
						eventlog.category = "VcfFile#destroy"
						vcfids
					end
					render text: "#{vcfids.size} VCF files were destroyed. Please reload the index page."
				else
					render text: "Aborted."
				end
			end
		else
			render text: "No entries selected"
		end
		# return true # smplids.to_json
	end

	
	def aqua_annotate
		
		## This is not necessary anymore after we use cancancan
		# if !current_user.is_admin? then
		#	alert_and_back_or_redirect("You cannot start the annotation process")
		#	return true
		# end
		
		_invalidate_cache
		@vcf_file = VcfFile.find(params[:id])
		@long_job = @vcf_file.annotate(params[:tools], http_remote_user())
		#if (!@vcf_file.nil?) and (@vcf_file.status == :CREATED or @vcf_file.status == :INCOMPLETE) then
		#	@vcf_annotater = AquaAnnotationProcess.new(params[:id])
		#	@long_job = LongJob.create_job({
		#			title: "AQuA VCF #{@vcf_file.name}",
		#      handle: @vcf_annotater,
		#      method: :start,
		#      user: http_remote_user(),
		#      queue: "annotation"
		#    }, false)
		#    @vcf_file.status = :ENQUEUED unless @long_jobs.nil?
		#		@vcf_file.save!
		#end
		respond_to do |format|
			format.js {render partial: "annotate"}
			# format.html { redirect_to vcf_file_url(@vcf_file), notice: 'Annotation process started' }
			format.json {head :no_content}
		end
	end
	
	def baf_plot
		if (params[:ids].nil? || params[:ids].size > 100) then
			render text: "Select 1-100 VCF files"
			return true
		end
		@vcf_files = VcfFile.find(params[:ids])
		respond_to do |format|
			format.html {render partial: "baf_stats", locals: {vcf_files: @vcf_files}}
			# format.html { redirect_to vcf_file_url(@vcf_file), notice: 'Annotation process started' }
			format.json {head :no_content}
		end
	end
	
	private
	
	def rename_sample(smpl_name)
		smpl_name       = smpl_name.name if smpl_name.is_a?(ActiveRecord::Base)
		stuff_to_remove = %w(
			reseq cln san fixed fix 
			cmpl wgs indels indel snps snp
			snp_indel vcf annotated
			filtered filter all_calls recal real nodup srt
		)
		mask            = Hash[stuff_to_remove.map {|x|
			["_", "-", "\\.", ""].map {|prefix|
				[Regexp.new("#{prefix}#{x}", true), ""]
			}
		}.flatten(1)]
		
		ret = smpl_name.dup
		mask.each do |pattern, replacement|
			ret.gsub!(pattern, replacement)
		end
		ret
	end
	
	def get_sample_sheet_tsv_data(params)
		# make a file in TSV format
		sample_sheet_table_id = params.keys.select {|k| k.to_s =~ /^sample_sheet_[0-9]+$/}.first
		selected_samples      = (params[sample_sheet_table_id] || [])
		samples               = params[:samples]
		samples.select! {|s| selected_samples.include?("#{s[:vcf_file_id]}/#{s[:vcf_sample_name]}")}
		
		header = (samples.first || {}).keys
		data   = [header.dup.join("\t")]
		data   += samples.map {|s|
			header.map {|colname|
				if colname == "users" and s[colname] != current_user.name then
					s[colname].to_s + ";" + current_user.name
				else
					if s[colname].is_a?(Array) then
						s[colname].join(";")
					elsif s[colname].is_a?(Hash)
						s[colname].to_json
					else
						s[colname]
					end
				
				end
				
			}.join("\t")
		}
	end
end
