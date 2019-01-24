class EntitiesController < ApplicationController
	# GET /entities
	# GET /entities.json
	include ApplicationHelper
	include TagsHelper

	def index
		@my_entities = current_user.editable(Entity).pluck(:id)
		@entities = current_user.visible(Entity)
		@entities = @entities.where("entities.id" => params[:ids]) unless params[:ids].nil?
		@entities = filter_collection @entities, [:name, :nickname, :internal_identifier, :notes, "tags.value"], 100
		
		respond_to do |format|
			format.html # index.html.erb
			format.json { render json: @entities }
		end
	end

	# GET /entities/1
	# GET /entities/1.json
	def show
		set_variables(params)
		
		respond_to do |format|
			format.html # show.html.erb
			format.json { render json: @entity }
		end
	end

	# GET /entities/new
	# GET /entities/new.json
	def new
		set_variables(params)
		specimen_template
		respond_to do |format|
			format.html # new.html.erb
			format.json { render json: @entity }
		end
	end

	# GET /entities/1/edit
	def edit
		set_variables(params)
		specimen_template
	end

	# POST /entities
	# POST /entities.json
	def create
		set_variables(params)
		specimen_template
		respond_to do |format|
			if @entity.save
				@created_specimen_probes = SpecimenProbe.create_from_template(params["specimen_templates"], @entity)
				if (params[:specimens]) then
					@entity.specimen_probes << SpecimenProbe.find(params[:specimens])
				end
				@entity.reload
				format.html { render action: "show", notice: 'Entity was successfully created.'}
				format.json { render json: @entity, status: :created, location: @entity }
			else
				format.html { render action: "new" }
				format.json { render json: @entity.errors, status: :unprocessable_entity }
			end
		end
	end

	# PUT /entities/1
	# PUT /entities/1.json
	def update
		set_variables(params)
		respond_to do |format|
			# @entity.specimen_probes = @selected_specimens
			if @entity.update_attributes(@opts)
				@created_specimen_probes = SpecimenProbe.create_from_template(params["specimen_templates"], @entity)
				format.html { render action: "show", notice: 'Entity was successfully updated.' }
				format.json { head :no_content }
			else
				format.html { render action: "edit" }
				format.json { render json: @entity.errors, status: :unprocessable_entity }
			end
		end
	end

	# DELETE /entities/1
	# DELETE /entities/1.json
	def destroy
		@entity = Entity.find(params[:id])
		@entity.destroy

		respond_to do |format|
			format.html { redirect_to entities_url }
			format.json { head :no_content }
		end
	end
	
	def assign_specimen_probe
		if params[:ids].nil? or params[:ids].size != 1 then
			render text: "Please select one entity."
			return false
		end
		
		entity = Entity.find(params[:ids]).first
		tags = SpecimenProbe.available_tags_by_category["STATUS"].map{|tag| [tag.value, tag.id]}
		tags = [["any tag", " "]] + tags
		require_params = {
			ids: params[:ids],
			name: " ",
			status_tag: tags
		}
		
		if determine_missing_params(require_params).size > 0 then
			render_table_details_params(require_params, label: "Filter specimens")
			return true
		else
			status_tag = nil
			status_tag = Tag.find(params[:status_tag]) unless params[:status_tag].nil? or params[:status_tag].to_s.strip == ""
		
			specimens = current_user.visible(SpecimenProbe)#.joins(:institution).where("institutions.id" => entity.institution.id)
			specimens = specimens.joins(:organism).where("entity_groups.organism_id" => entity.organism.id)
			specimens = specimens.where("specimen_probes.name RLIKE '.*#{(ActiveRecord::Base::sanitize params[:name]).strip[1..-2]}.*'") if params[:name].to_s.strip != ""
			specimens = specimens.joins(:tags).where("tags.category = 'STATUS' AND tags.value = '#{status_tag.value}'") unless status_tag.nil?
			specimens.instance_variable_set(:@_table_selected, entity.specimen_probe_ids)
			require_params = {
				ids: params[:ids],
				name: params[:name],
				status_tag: params[:status_tag],
				specimen: specimens
			}
			
			if determine_missing_params(require_params).size > 0 then
				render_table_details_params(require_params, label: "Assign specimen to Entity.")
				return true
			else
				success = false
				x = 0
				SpecimenProbe.transaction do 
					x = SpecimenProbe.where(id: params[:specimen]).update_all(entity_id: entity.id)
					success = x == params[:specimen].uniq.size
					raise ActiveRecord::Rollback if !success
				end
				if success then
					render text: "#{x} Specimen updated."
				else
					render text: "[ERROR] specimen were not updated. Only #{x} of #{params[:specimen].uniq.size} could be updated. #{params.pretty_inspect}"
				end
				
			end
		end
	end
	
	def assign_entity_group
		if params[:ids].nil? or params[:ids].size != 1 then
			render text: "Please select one Entity."
			return false
		end
		
		require_params = {
			ids: params[:ids],
			name: " ",
			contact: " "
		}
		
		if determine_missing_params(require_params).size > 0 then
			render_table_details_params(require_params, label: "Specify the entity groups you want to use. Leave this empty to retrieve all entity groups")
			return true
		else 
			entity = Entity.find(params[:ids]).first
			entity_groups = current_user.visible(EntityGroup).where("entity_groups.organism_id" => entity.organism.id)
			entity_groups = entity_groups.where("entity_groups.name RLIKE '.*#{(ActiveRecord::Base::sanitize params[:name].strip)[1..-2]}.*'") unless params[:name].to_s.strip == ""
			entity_groups = entity_groups.where("entity_groups.contact RLIKE '.*#{(ActiveRecord::Base::sanitize params[:contact].strip)[1..-2]}.*'") unless params[:contact].to_s.strip == ""
			entity_groups = entity_groups.order("entity_groups.updated_at DESC")
			entity_groups.instance_variable_set(:@_table_selected, entity.entity_group_id)
			entity_groups.instance_variable_set(:@_table_select_type, :radio)
			require_params = {
						ids: params[:ids],
						name: params[:name],
						contact: params[:contact],
						"entity_groups" => entity_groups
			}
			if determine_missing_params(require_params).size > 0 then
				render_table_details_params(require_params, label: "Assign specimen to entity. ")
				return true
			else
				if params[:entity_groups].size != 1 then
					render text: "[ERROR] Please select one entity group."
					return true
				else
					entity_group = EntityGroup.find(params[:entity_groups]).first
					entity.entity_group = entity_group
					success = entity.save
					if success then
					render text: "#{entity.name} assigned to #{entity_group.name}"
					else
						render text: "[ERROR] Entity could not be re-assigned. #{entity.errors.messages.to_s}"
					end
				end
			end
		end
	end

private
# makes sure the date of first diagnosis is properly set
	def get_submitted_attributes
		return if params[:entity].nil?
		opts = (params[:entity] || {}).dup
		year, month, day = params[:entity]["date_first_diagnosis(1i)"].to_i, params[:entity]["date_first_diagnosis(2i)"].to_i, params[:entity]["date_first_diagnosis(3i)"].to_i
		opts.delete("date_first_diagnosis(1i)")
		opts.delete("date_first_diagnosis(2i)")
		opts.delete("date_first_diagnosis(3i)")
		date = nil
		if year.to_i != 0 then
			month = 1 if month.to_i == 0
			day = 1 if day.to_i == 0
			# date = Date.civil(year, month, day)
			date = DateTime.new(year, month, day, 12, 0, 0, '0')
		end
		opts["date_first_diagnosis"] = date# Date.civil(year, month, day)
		@opts = opts
	end

	def set_variables(params)
		get_submitted_attributes
		if !params[:id].nil? then # edit or show
			#@entity = Entity.find(params[:id])
			@entity = current_user.visible(Entity).find(params[:id])
		elsif params[:entity].nil? # new action
			@entity = Entity.new
		else # edit/create action
			@entity = Entity.new(@opts)
		end
		
		inst_id = nil # @entity.institution_id
		eg_id = @entity.entity_group_id
		
		inst_id = params[:institution_id] if params[:institution_id].to_s.to_i > 0
		
		@institutions = Institution.order(:name)
		
		@institution = @entity.institution
		if @institution.nil? then
			if inst_id.nil? then
				@institution = Institution.new
			else
				@institution = @institutions.find(inst_id)
			end
		else
			inst_id = @institution.id
		end
		
		@entity_groups = []# EntityGroup.scoped
		if !inst_id.nil? then
			@entity_groups = EntityGroup.joins(:institution).where("institutions.id" => inst_id).order(:name)
		elsif !inst_id.nil?
			@entity_groups = @institution.entity_groups
		end 
		
		@entity_group = @entity.entity_group
		if @entity_group.nil?
			eg_id = params[:entity_group_id] if params[:entity_group_id].to_s.to_i > 0 && @entity_groups.size > 0
			if eg_id.nil? then
				@entity_group = EntityGroup.new
			else
				@entity_group = @entity_groups.where("entity_groups.id" => eg_id).first
				@entity_group = EntityGroup.new if @entity_group.nil? # this can happen when the user changes the institution after selecting a entity group
			end
		end
		inst_id = @entity_group.institution_id
		
		
		@entity.entity_group_id = @entity_group.id
		# @entity.institution_id = @institution.id
		
		@tags = Entity.available_tags
		@selected_tags = @entity.tags

		if !params[:tags].nil? then
			@selected_tags = (Tag.find(params[:tags].values.flatten.reject{|id| id.to_s == ""})).uniq
		end 
		
		@entity.tags = @selected_tags
		
		@specimens = (@entity.specimen_probes || [])
		if params[:show_specimens].to_i > 0 then
			@specimens = current_user.visible(SpecimenProbe)
																.order("updated_at DESC")
																.limit(500)
			@specimens = (@specimens + (@entity.specimen_probes || [])).uniq
		end
		@selected_specimens = @entity.specimen_probes
		if !params[:specimens].nil? then
			@selected_specimens = SpecimenProbe.find(params[:specimens])
		else
			@selected_specimens = [] if params[:action] == "update" # in that case the user wants to delete the link
		end
		
		@proposed_name = [] # Institution name + Entity ID
		@proposed_nickname = []
		
		#nextid = (Entity.maximum(:id) || 0) + 1
		nextid = @institution.entities.count + 1
		
		@proposed_name = [@institution.name, "#", nextid]
		@proposed_nickname = [""]
		@proposed_name = @proposed_name.join("")
		@proposed_nickname = @proposed_nickname.join("")
		if @created_specimen_probes.nil?
			if params[:created_specimens].nil? then
				@created_specimen_probes = []
			else
				@created_specimen_probes = params[:created_specimens]
			end
		end 
		@specimen_template = {} if @specimen_template.nil?
	end
	
	def specimen_template
		labs = (SpecimenProbe.where("lab IS NOT NULL").select(:lab).uniq.pluck(:lab) || []).sort
		tags = SpecimenProbe.available_tags true
		# samples = current_user.visible(Sample).order(:name).map{|s| [s.name, s.id]}
		
		@specimen_template = {
				name: {type: :string, placeholder: "required"},
				"tags[STATUS]" => {type: :combobox, options: tags["STATUS"].map{|tag| [tag.value, tag.id]}, validonly: true},
				"tags[TISSUE]" => {type: :combobox, options: tags["TISSUE"].map{|tag| [tag.value, tag.id]}, validonly: true},
				"lab" => {type: :autocomplete, options: labs},
				"lab_contact" => {type: :string, placeholder: "optional"},
				notes: {type: :string, placeholder: "optional"},
				internal_identifier: {type: :string, placeholder: "optional"},
				tumor_content: {type: :string, placeholder: "optional"},
				tumor_content_notes: {type: :string, placeholder: "optional"},
				date_day: {type: :number, placeholder: "optional"},
				date_month: {type: :number, placeholder: "optional"},
				date_year: {type: :number, placeholder: "optional"},
				# "samples[1]" => {type: :combobox, options: samples, validonly: true},
				# "samples[2]" => {type: :combobox, options: samples, validonly: true},
				# "samples[3]" => {type: :combobox, options: samples, validonly: true},
				# "samples[4]" => {type: :combobox, options: samples, validonly: true}
			}
			(tags.keys - ["STATUS", "TISSUE"]).sort.each do |category|
				@specimen_template["tags[#{category}]"] = {type: :combobox, options: tags[category].map{|tag| [tag.value, tag.id]}, validonly: true}
			end
	end
	
end
