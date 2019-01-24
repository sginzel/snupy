class SpecimenProbesController < ApplicationController
	include ApplicationHelper
	include TagsHelper
	# GET /specimen_probe
	# GET /specimen_probe.json
	def index
		@my_specimen_probe = current_user.editable(SpecimenProbe).pluck(:id)
		@specimen_probe = current_user.visible(SpecimenProbe)
		#@specimen_probe = SpecimenProbe.joins(:entity_group).where("entity_groups.institution_id" => current_user.institution_ids)
		@specimen_probe = @specimen_probe.where("specimen_probes.id" => params[:ids]) unless params[:ids].nil?
		@specimen_probe = @specimen_probe.includes([:tags, :entity_group, :entity, :samples])
		@specimen_probe = filter_collection @specimen_probe, [:name, "tags.value", :lab, :internal_identifier, :date_year], 100
		
		respond_to do |format|
			format.html # index.html.erb
			format.json { render json: @specimen_probe }
		end
	end

	# GET /specimen_probe/1
	# GET /specimen_probe/1.json
	def show
		set_required_variables(params)

		respond_to do |format|
			format.html # show.html.erb
			format.json { render json: @specimen_probe }
		end
	end

	# GET /specimen_probe/new
	# GET /specimen_probe/new.json
	def new
		set_required_variables(params)
		respond_to do |format|
			format.html # new.html.erb
			format.json { render json: @specimen_probe }
		end
	end

	# GET /specimen_probe/1/edit
	def edit
		set_required_variables(params)
		
	end

	# POST /specimen_probe
	# POST /specimen_probe.json
	def create
		set_required_variables(params)
		
		respond_to do |format|
			if @specimen_probe.save
				@specimen_probe.reload
				flash[:notice] = 'Specimen was successfully created.'
				format.html { redirect_to controller: "specimen_probes", action: "show", id: @specimen_probe}
				format.json { render json: @specimen_probe, status: :created, location: @specimen_probe }
			else
				format.html { render action: "new" }
				format.json { render json: @specimen_probe.errors, status: :unprocessable_entity }
			end
		end
	end

	# PUT /specimen_probe/1
	# PUT /specimen_probe/1.json
	def update
		set_required_variables(params)
		respond_to do |format|
			if @specimen_probe.update_attributes(params[:specimen_probe])
				flash[:notice] = 'Specimen was successfully updated.'
				format.html { redirect_to controller: "specimen_probes", action: "show", id: @specimen_probe}
				# format.html { redirect_to "/specimen_probes", notice: 'SpecimenProbe was successfully updated.', ids: [@specimen_probe] }
				format.json { head :no_content }
			else
				format.html { render action: "edit" }
				format.json { render json: @specimen_probe.errors, status: :unprocessable_entity }
			end
		end
	end

	# DELETE /specimen_probe/1
	# DELETE /specimen_probe/1.json
	def destroy
		@specimen_probe = SpecimenProbe.find(params[:id])
		@specimen_probe.destroy

		respond_to do |format|
			format.html { redirect_to specimen_probes_url }
			format.json { head :no_content }
		end
	end
	
	def assign_sample
		if params[:ids].nil? or params[:ids].size != 1 then
			render text: "Please select one specimen."
			return false
		end
		
		require_params = {
			ids: params[:ids],
			name: " ",
			nickname: " ",
			patient: " ",
		}
		
		if determine_missing_params(require_params).size > 0 then
			render_table_details_params(require_params, label: "You can specify which samples you want to see. Leave this empty to retrieve all samples")
			return true
		else 
			specimen = SpecimenProbe.find(params[:ids]).first
			smpls = current_user.visible(Sample).joins(:organism).where("vcf_files.organism_id" => specimen.organism.id)
			smpls = smpls.where("samples.name RLIKE '.*#{(ActiveRecord::Base::sanitize params[:name].strip)[1..-2]}.*'") unless params[:name].to_s.strip == ""
			smpls = smpls.where("samples.nickname RLIKE '.*#{(ActiveRecord::Base::sanitize params[:nickname].strip)[1..-2]}.*'") unless params[:nickname].to_s.strip == ""
			smpls = smpls.where("samples.patient RLIKE '.*#{(ActiveRecord::Base::sanitize params[:patient].strip)[1..-2]}.*'") unless params[:patient].to_s.strip == ""
			smpls = smpls.order("samples.updated_at DESC")
			smpls.instance_variable_set(:@_table_selected, specimen.sample_ids)
			require_params = {
						ids: params[:ids],
						patient: params[:patient],
						name: params[:name],
						nickname: params[:nickname],
						# samples: current_user.visible(Sample).map{|sp| [sp.name, sp.id]},
						"samples" => smpls
			}
			if determine_missing_params(require_params).size > 0 then
				render_table_details_params(require_params, label: "Assign specimen to samples. ")
				return true
			else
				success = false
				x = 0
				Sample.transaction do 
					x = Sample.joins(:organism).where("vcf_files.organism_id" => specimen.organism.id).where("samples.id" => params[:samples]).update_all(specimen_probe_id: specimen.id)
					success = x == params[:samples].uniq.size
					raise ActiveRecord::Rollback if !success
				end
				smpl_names = Sample.where(id: params[:samples]).pluck(:name)
				if success then
					render text: "#{specimen.name} linked to [#{smpl_names.sort.join(", ")}] (#{x} links added/modified)"
				else
					render text: "[ERROR] samples were not updated. Only #{x} of #{params[:samples].uniq.size} could be updated. #{params.pretty_inspect}"
				end
				
			end
		end
	end
	
	def assign_entity
		if params[:ids].nil? or params[:ids].size != 1 then
			render text: "Please select one specimen."
			return false
		end
		
		require_params = {
			ids: params[:ids],
			name: " ",
			nickname: " ",
			internal_identifier: " "
		}
		
		if determine_missing_params(require_params).size > 0 then
			render_table_details_params(require_params, label: "Specify the entities you want to use. Leave this empty to retrieve all entities")
			return true
		else 
			specimen = SpecimenProbe.find(params[:ids]).first
			entities = current_user.visible(Entity).joins(:organism).where("entity_groups.organism_id" => specimen.organism.id)
			entities = entities.where("entities.name RLIKE '.*#{(ActiveRecord::Base::sanitize params[:name].strip)[1..-2]}.*'") unless params[:name].to_s.strip == ""
			entities = entities.where("entities.nickname RLIKE '.*#{(ActiveRecord::Base::sanitize params[:nickname].strip)[1..-2]}.*'") unless params[:nickname].to_s.strip == ""
			entities = entities.where("entities.internal_identifier RLIKE '.*#{(ActiveRecord::Base::sanitize params[:internal_identifier].strip)[1..-2]}.*'") unless params[:internal_identifier].to_s.strip == ""
			entities = entities.order("entities.updated_at DESC")
			entities.instance_variable_set(:@_table_selected, specimen.entity_id)
			entities.instance_variable_set(:@_table_select_type, :radio)
			require_params = {
						ids: params[:ids],
						internal_identifier: params[:internal_identifier],
						name: params[:name],
						nickname: params[:nickname],
						# samples: current_user.visible(Sample).map{|sp| [sp.name, sp.id]},
						"entities" => entities
			}
			if determine_missing_params(require_params).size > 0 then
				render_table_details_params(require_params, label: "Assign specimen to entity. ")
				return true
			else
				if params[:entities].size != 1 then
					render text: "[ERROR] Please select one entity."
					return true
				else
					entity = Entity.find(params[:entities]).first
					specimen.entity = entity
					success = specimen.save
					if success then
					render text: "#{specimen.name} linked to #{entity.name}"
					else
						render text: "[ERROR] Specimen could not be linked. #{specimen.errors.messages.to_s}"
					end
				end
			end
		end
	end
	
	
	
private
	def set_required_variables(params)
		if !params[:id].nil? then # SpecimenProbe exists and is edited
			#@specimen_probe = SpecimenProbe.find(params[:id])
			@specimen_probe = current_user.visible(SpecimenProbe).find(params[:id])
		elsif params[:specimen_probe].nil? # no entity group submited - new action
			@specimen_probe = SpecimenProbe.new
		else
			@specimen_probe = SpecimenProbe.new(params[:specimen_probe])
		end
		
		@institutions = (current_user.is_admin?)?(Institution.scoped):(current_user.institutions)
		@institution = Institution.new
		if !@specimen_probe.entity.nil? then
			@institution = @specimen_probe.entity.institution
		elsif !params[:institution_id].nil? & @institutions.map(&:id).include?(params[:institution_id].to_i) then
			@institution = Institution.find(params[:institution_id])
		end
		
		@entity_groups = []
		@entity_groups = @institution.entity_groups

		@selected_entity = (@specimen_probe.entity || Entity.new)
		@selected_entity_group = (@selected_entity.entity_group || EntityGroup.new)
		
		if params[:entity_group_id].to_s.to_i != 0 and !@selected_entity.persisted? then
			@selected_entity_group = EntityGroup.find(params[:entity_group_id])
			# @entities = (current_user.visible(Entity).order(:name).includes(:tags)  + [@specimen_probe.entity])
		end
		@entities = (@selected_entity_group.entities || [])

		if !params[:entity_id].nil? then
			@selected_entity = Entity.find(params[:entity_id])
		end
		@specimen_probe.entity = @selected_entity
		
		
		@samples = (@specimen_probe.samples || [])
		if !@institution.id.nil? then
			if params[:show_samples] then
				@samples = current_user.visible(Sample)
										.where(specimen_probe_id: nil)
										.order("updated_at DESC").limit(500)
				@samples = @samples.joins(:vcf_file).where("vcf_files.organism_id" => @specimen_probe.organism.id) unless @specimen_probe.organism.nil?
				@samples = ((@specimen_probe.samples || []) + @samples).uniq
			end
		end
		@selected_samples = @specimen_probe.samples
		if !params[:sample_ids].nil? then
			@selected_samples = Sample.find(params[:sample_ids])
		else
			@selected_samples = [] if params[:action] == "update" # in that case the user wants to delete the link
		end 
		
		@tags = SpecimenProbe.available_tags true
		@selected_tags = @specimen_probe.tags_by_category
		@selected_tags["STATUS"] = [] if @selected_tags["STATUS"].nil?
		@selected_tags["TISSUE"] = [] if @selected_tags["TISSUE"].nil?
		if !params[:tags].nil? then # update list
			@selected_tags = {}
			Tag.find(params[:tags].values.flatten.reject{|id| id.to_s == ""}).each do |tag|
				@selected_tags[tag.category] = [] if @selected_tags[tag.category].nil?
				@selected_tags[tag.category] << tag
			end
			 
		end
		# @tags_to_link = (@selected_tags.values.flatten || [])
		# @specimen_probe.queryable = @tags_to_link.any?{|tag| tag.category == "STATUS"} && @tags_to_link.any?{|tag| tag.category == "TISSUE"}
		@specimen_probe.tags = @selected_tags.values.flatten
		@specimen_probe.samples = @selected_samples
	end

end
