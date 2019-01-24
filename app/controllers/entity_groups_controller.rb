# noinspection ALL
class EntityGroupsController < ApplicationController
	include ApplicationHelper
	# GET /entity_groups
	# GET /entity_groups.json
	def index
		@my_entity_groups = current_user.editable(EntityGroup).pluck(:id)
		# @entity_groups = EntityGroup.where(institution_id: current_user.institution_ids)
		@entity_groups = current_user.visible(EntityGroup)
		@entity_groups = filter_collection @entity_groups, [:name, :contact], 100
		@entity_groups.includes([:tags, :entities, :specimen_probes])
		# @entity_groups = @entity_groups.limit(params[:count].to_i) if (params[:count])
		
		respond_to do |format|
			format.html # index.html.erb
			format.json { render json: @entity_groups }
		end
	end

	# GET /entity_groups/1
	# GET /entity_groups/1.json
	def show
		set_required_variables(params)

		respond_to do |format|
			format.html # show.html.erb
			format.json { render json: @entity_group }
		end
	end

	# GET /entity_groups/new
	# GET /entity_groups/new.json
	def new
		set_required_variables(params)
		entity_template
		respond_to do |format|
			format.html # new.html.erb
			format.json { render json: @entity_group }
		end
	end

	# GET /entity_groups/1/edit
	def edit
		set_required_variables(params)
		entity_template
	end

	# POST /entity_groups
	# POST /entity_groups.json
	def create
		set_required_variables(params)
		entity_template
		respond_to do |format|
			if @entity_group.save
				@created_entities = Entity.create_from_template(params["entity_templates"], @entity_group)
				#format.html { redirect_to @entity_group, notice: 'Entity group was successfully created.' }
				@entity_group.reload
				format.html { render action: "show", id: @entity_group, notice: 'Entity group was successfully created.' }
				format.json { render json: @entity_group, status: :created, location: @entity_group }
			else
				format.html { render action: "new" }
				format.json { render json: @entity_group.errors, status: :unprocessable_entity }
			end
		end
	end

	# PUT /entity_groups/1
	# PUT /entity_groups/1.json
	def update
		set_required_variables(params)

		respond_to do |format|
			if @entity_group.update_attributes(params[:entity_group])
				@created_entities = Entity.create_from_template(params["entity_templates"], @entity_group)
				format.html { render action: "show", notice: 'Entity group was successfully updated.' }
				format.json { head :no_content }
			else
				format.html { render action: "edit" }
				format.json { render json: @entity_group.errors, status: :unprocessable_entity }
			end
		end
	end

	# DELETE /entity_groups/1
	# DELETE /entity_groups/1.json
	def destroy
		@entity_group = EntityGroup.find(params[:id])
		@entity_group.destroy

		respond_to do |format|
			format.html { redirect_to entity_groups_url }
			format.json { head :no_content }
		end
	end
	
	def batch_create
		@sheet = nil
		@dataset_sheet_template = EntityGroup.upload_template.keys.map{|k|
			[k,
			 {id: k,
			  type: :string
			 }
			]
		}
		@dataset_sheet_template = Hash[@dataset_sheet_template]
		@dataset_sheet_template[:institution][:placeholder] = "Valid institution name"
		@dataset_sheet_template[:organism][:placeholder] = "Valid organism name"
		@dataset_sheet_template[:entity_group][:placeholder] = "New or existing entity group name"
		@dataset_sheet_template[:entity][:placeholder] = "New or existing entity name"
		@dataset_sheet_template[:specimen_probe][:placeholder] = "New or existing specimen name"
		@dataset_sheet_template[:sample][:placeholder] = "Exsting sample name (requires permission)"
		@dataset_sheet_template[:entity_tags][:placeholder] = "Use | as seperator for valid Entity Tags"
		@dataset_sheet_template[:specimen_probe_tags][:placeholder] = "Use | as seperator for valid Specimen Tags"
		if not params[:sheet].nil? then
			if params[:commit] == 'Submit' then
				ActiveRecord::Base.transaction do
					begin
						@sheet = EntityGroup.create_from_upload(params[:sheet].tempfile.path, current_user)
					rescue CSV::MalformedCSVError => e
						@sheet = nil
						flash[:error] = "Error when parsing CSV file: " + e.message
					end
					flash[:notice] = "Nothing was added, because you requested a dry run." if params[:dryrun]
					raise ActiveRecord::Rollback if params[:dryrun]
				end
			end
		elsif not params[:sheet_form].nil? then
			if params[:commit] == 'Submit' then
				ActiveRecord::Base.transaction do
					@sheet = EntityGroup.create_from_upload(params[:sheet_form], current_user)
					raise ActiveRecord::Rollback if params[:dryrun]
				end
			elsif params[:commit] == 'Download this template'
				data = [params[:sheet_form].first[1].keys.join("\t")]
				data += params[:sheet_form].map {|row, rec|
					rec.values.join("\t")
				}
				respond_to do |format|
					format.all {
						send_data(data.join("\n"),
								  filename: "DatasetUploadTemplate.csv",
								  type: "text/plain")
					}
				end
			end
		end
	end
	
	def show_dataset_summary
		if params[:ids].nil? or params[:ids].size == 0 or params[:ids].size > 1000 then
			render text: "Please select 1-1000 entity groups."
			return false
		end
		# users can access this action through the index page, which they shouldnt be blocked from
		# thus we need to check if the submitted ids are allowed for that user
		ids = params[:ids].nil? ? [] : params[:ids].map(&:to_i)
		ids = current_user.visible(EntityGroup).where("entity_groups.id" => ids).pluck(:id)
		entity_groups = EntityGroup.dataset_summary(ids)
		render partial: "home/data_overview", locals: {
					data_overview: entity_groups}
	end

	def assign_entity
		if params[:ids].nil? or params[:ids].size != 1 then
			render text: "Please select one Entity Group."
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
			entity_group = EntityGroup.find(params[:ids]).first
			entities = current_user.visible(Entity).joins(:organism).where("entity_groups.organism_id" => entity_group.organism.id)
			entities = entities.where("entities.name RLIKE '.*#{(ActiveRecord::Base::sanitize params[:name].strip)[1..-2]}.*'") unless params[:name].to_s.strip == ""
			entities = entities.where("entities.nickname RLIKE '.*#{(ActiveRecord::Base::sanitize params[:nickname].strip)[1..-2]}.*'") unless params[:nickname].to_s.strip == ""
			entities = entities.where("entities.internal_identifier RLIKE '.*#{(ActiveRecord::Base::sanitize params[:internal_identifier].strip)[1..-2]}.*'") unless params[:internal_identifier].to_s.strip == ""
			entities = entities.order("entities.updated_at DESC")
			entities.instance_variable_set(:@_table_selected, entity_group.entity_ids)
			entities.instance_variable_set(:@_table_select_type, :select)
			require_params = {
					ids: params[:ids],
					internal_identifier: params[:internal_identifier],
					name: params[:name],
					nickname: params[:nickname],
					# samples: current_user.visible(Sample).map{|sp| [sp.name, sp.id]},
					"entities" => entities
			}
			if params[:entities_length].nil? && determine_missing_params(require_params).size > 0 then
				render_table_details_params(require_params, label: "Assign entity group to entities.")
				return true
			else
				if (params[:entities] || []).size == 0 && params[:confirm].nil? then
					require_params = {
							ids: params[:ids],
							internal_identifier: params[:internal_identifier],
							name: params[:name],
							nickname: params[:nickname],
							# samples: current_user.visible(Sample).map{|sp| [sp.name, sp.id]},
							"entities" => ["NO", "YES"]
					}
					render_table_details_params(require_params, label: "Are you sure you want to remove all entities from this group?")
					return true
				else
					if params[:entities] == "YES" then
						entity_group.entities = []
						success = entity_group.save
						if success then
							render text: "[Success] Removed all entites from #{entity_group.name}."
						else
							render text: "[Error] saving #{entity_group.name}.", status: 500
						end
						return true
					elsif params[:entities] == "NO" then
						render text: "[Abort] canceled to modify #{entity_group.name}."
						return true
					end
					if !entity_group.nil? then
						entities = Entity.find(params[:entities])
						if entities.map(&:id).sort == entity_group.entity_ids.sort then
							render text: "[Success] No changes made to #{entity_group.name}."
							return true
						end
						success = true
						cnt = 0
						Entity.transaction do
							last_msg = ""
							entities.each do |ent|
								ent.entity_group = entity_group
								success = success && ent.save
								break unless success
								last_msg = ent.errors.messages.to_s
								cnt += 1
							end
							if cnt == entities.size then
								render text: "[Success] #{entity_group.name} now has #{cnt} entities."
								return true
							else
								render text: "[Error] Only #{cnt} of #{entities.size} were able to have a new entity group. We roll back. #{last_msg}", status: 500
								raise ActiveRecord::Rollback, "Not all Entities could be saved. So we rolled back."
								return true
							end
						end
					else
						render text: "[ERROR] Enttiy Group not found.", status: 500
						return true
					end
				end
			end
		end
	end

	def assign_tag(ids)
		mdl = Kernel.const_get(self.class.name.gsub("Controller", "").singularize.to_sym)

		if params[:ids].nil? or params[:ids].size != 1 then
			render text: "Please select one Entity Group."
			return false
		end

		categories = mdl.available_tags_by_category.keys
		require_params = {
				ids: params[:ids],
				category: categories
		}

		if determine_missing_params(require_params).size > 0 then
			render_table_details_params(require_params, label: "Select a category")
			return true
		else
			tags = mdl.available_tags_by_category[params[:category]]
			require_params = {
					ids: params[:ids],
					category: params[:category],
					tags: tags
			}
			if determine_missing_params(require_params).size > 0 then
				render_table_details_params(require_params, label: "Select a tag to apply")
				return true
			else
				objs = mld.find(ids)
				tags = Tag.find(params[:tags])
				tags.each do |t|
					t.push_objects(objs)
				end
			end
		end
	end

private
	# noinspection RubyResolve
	def set_required_variables(params)
		if !params[:id].nil? then # EntityGroup exists and is edited
			# @entity_group = EntityGroup.find(params[:id])
			@entity_group = current_user.visible(EntityGroup).find(params[:id])
		elsif params[:entity_group].nil? # no entity group submited - new action
			@entity_group = EntityGroup.new
		else
			@entity_group = EntityGroup.new(params[:entity_group])
		end
		
		if current_user.is_admin then
			@users = User.scoped
		else
			@users = current_user.collegues
		end
		if !params[:users].nil? then
			@selected_users = User.find(params[:users])
		else
			@selected_users = (@entity_group.users.size > 0)?(@entity_group.users):([current_user])
		end
		@entity_group.users = @selected_users
		
		if current_user.is_admin then
			@institutions = Institution.scoped
		else
			@institutions = current_user.institutions
		end
		@selected_institution = (@entity_group.institution || Institution.new)
		if !params[:institution_id].nil? then
			@selected_institution = Institution.find(params[:institution_id].first)
		end 
		
		@organisms = Organism.all
		@selected_organism = @entity_group.organism || Organism.new()
		if !(params[:organism_name].to_s == "") then
			@selected_organism = Organism.find_by_name(params[:organism_name])
		end
		
		#@entities = current_user.visible(Entity)
		#						.includes(:institution)
		#						.where("institutions.id" => @selected_institution)
		#						.order("entities.updated_at DESC")
		#						.limit(500)
		@entities = @entity_group.entities
		@selected_entities = @entity_group.entities
		if !params[:entity_ids].nil? then
			@selected_entities = Entity.find(params[:entity_ids])
		end 
		
		@experiments = current_user.visible(Experiment).where("experiments.institution_id" => @selected_institution.id)
		@selected_experiments = @entity_group.experiments
		if !params[:experiment_ids].nil? then
			@selected_experiments = Experiment.find(params[:experiment_ids])
		end 
		
		@entity_group.institution = @selected_institution
		@entity_group.entities = @selected_entities
		@entity_group.experiments = @selected_experiments
		@entity_group.organism_id = @selected_organism.id
		
		@proposed_name = ""
		@proposed_name = "#{@selected_institution.name}#{@selected_institution.entity_groups.count+1}" unless @selected_institution.nil?
		@entity_template = {} if @entity_template.nil?
	end
	
	def entity_template
		tags = Entity.available_tags_by_category
		@entity_template = {
				name: {type: :string, placeholder: "required"},
				nickname: {type: :string, placeholder: "optional"},
				internal_identifier: {type: :string, placeholder: "optional"},
				contact: {type: :string, placeholder: "optional"},
				family_members_available: {type: :boolean},
				"tags[CLASS]" => {type: :combobox, options: tags["CLASS"].map{|tag| [tag.value, tag.id]}, validonly: true},
				"tags[DISEASE]" => {type: :combobox, options: tags["DISEASE"].map{|tag| [tag.value, tag.id]}, validonly: true},
				"tags[AGE_GROUP]" => {type: :combobox, options: tags["AGE_GROUP"].map{|tag| [tag.value, tag.id]}, validonly: true},
				"tags[GENDER]" => {type: :combobox, options: tags["GENDER"].map{|tag| [tag.value, tag.id]}, validonly: true}
			}
	end
	
end
