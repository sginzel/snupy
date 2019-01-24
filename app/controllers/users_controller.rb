class UsersController < ApplicationController
	before_filter :admin_required, :only => [ :new, :edit, :create, :delete, :destroy, :update ]
	def _invalidate_cache
		# expire_page :action => :index
		# expire_action :action => :index
		# invalidates all caches of samples for all users
		expire_fragment(/samples/)
		expire_fragment(/vcf_files/)
	end

	# GET /users
	# GET /users.json
	def index
		if current_user.is_admin
			@users = User.all
		else
			@users = []
		end

		respond_to do |format|
			format.html # index.html.erb
			format.json { render json: @users }
		end
	end

	# GET /users/1
	# GET /users/1.json
	def show
		@user = find_myself(params[:id])# User.find(params[:id])

		respond_to do |format|
			format.html # show.html.erb
			format.json { render json: @user }
		end
	end

	# GET /users/new
	# GET /users/new.json
	def new
		@user = User.new
		@institutions = Institution.all
		@lists = GenericList.all
		@samples = current_user.visible(Sample)
		@entity_groups = current_user.visible(EntityGroup)
		@visible_samples = Hash[@user.visible(Sample).map{|s| [s.id, s]}]
		
		respond_to do |format|
			format.html # new.html.erb
			format.json { render json: @user }
		end
	end

	# GET /users/1/edit
	def edit
		@user = find_myself(params[:id])# User.find(params[:id])
		@institutions = Institution.all
		@lists = GenericList.all
		@samples = current_user.visible(Sample)
		@entity_groups = current_user.visible(EntityGroup)
		# visible samples for the @user is different from the visibility of samples for the admin
		@visible_samples = Hash[@user.visible(Sample).map{|s| [s.id, s]}]
		
	end

	# POST /users
	# POST /users.json
	def create
		@user = User.new(params[:user])
		@institutions = Institution.all
		@lists = GenericList.all
		
		respond_to do |format|
			if @user.save
				# @user.samples = Sample.find_all_by_id(params[:samples])
				@user.samples = Sample.find_all_by_id(params[:samples])
				@user.entity_groups = EntityGroup.find_all_by_id(params[:entity_groups])
				@user.experiments = Experiment.find_all_by_id(params[:experiments])
				@user.generic_lists = GenericList.find_all_by_id(params[:generic_lists])
				# @user.institutions = Institution.find_all_by_id(params[:institutions])
				@user.affiliations.destroy_all # make sure there are not affiliations
				Affiliation.create_from_params(@user, params[:institution])
				if params["api_key"] == "1" then
					ApiKey.generate(@user)
				end
				format.html { redirect_to @user, notice: 'User was successfully created.' }
				format.json { render json: @user, status: :created, location: @user }
			else
				format.html { render action: "new" }
				format.json { render json: @user.errors, status: :unprocessable_entity }
			end
		end
	end

	# PUT /users/1
	# PUT /users/1.json
	def update
		@user = find_myself(params[:id])# User.find(params[:id])
		@institutions = Institution.all
		@lists = GenericList.all
		# @user.institutions = Institution.find_all_by_id(params[:institutions])
		respond_to do |format|
			if @user.update_attributes(params[:user])
				previous_affiliations = @user.affiliation_ids # make sure there are not affiliations
				Affiliation.create_from_params(@user, params[:institution])
				Affiliation.where(id: previous_affiliations).destroy_all if previous_affiliations.size > 0
				@user.samples = Sample.find_all_by_id(params[:samples])
				@user.entity_groups = EntityGroup.find_all_by_id(params[:entity_groups])
				@user.experiments = Experiment.find_all_by_id(params[:experiments])
				@user.generic_lists = GenericList.find_all_by_id(params[:generic_lists])
				if params["api_key_remove"] == "1" then
					ApiKey.remove(@user.api_key) unless @user.api_key.nil?
				end
				if params["api_key_refresh"] == "1" and params["api_key_remove"] != "1" then
					ApiKey.generate(@user, true)
				end
				if params["api_key"] == "1" and params["api_key_remove"] != "1" then
					ApiKey.generate(@user)
				end
				_invalidate_cache
				format.html { redirect_to @user, notice: 'User was successfully updated.' }
				format.json { head :no_content }
			else
				format.html { redirect_to action: "edit" }
				format.json { render json: @user.errors, status: :unprocessable_entity }
			end
		end
	end

	# DELETE /users/1
	# DELETE /users/1.json
	def destroy
		@user = find_myself(params[:id])# User.find(params[:id])
		@user.destroy
		_invalidate_cache
		respond_to do |format|
			format.html { redirect_to users_url }
			format.json { head :no_content }
		end
	end

	def access_control_list
		@users = User.scoped
		@users = current_user.collegues unless current_user.is_admin?
		@users = filter_collection @users, [:name, :full_name]
		
		@acl = []
		if (params[:users] || []).size > 0 then
			if !params[:object_type].nil? then
				mdl = case params[:object_type]
				when "VcfFile"
					VcfFile
				when "Sample"
					Sample
				when "Specimen"
					SpecimenProbe
				when "Entity"
					Entity
				when "EntityGroup"
					EntityGroup
				when "Experiment"
					Experiment
				when "Panel"
					GenericGeneList
				else
					String
				end
				users = User.find(params[:users])
				all_samples = {}
				idcol = "#{mdl.table_name}.#{mdl.primary_key}"
				namecol = "#{mdl.table_name}.name"
				users_to_samples = Hash[users.map{|u|
					ret = {
						owned: {},
						visible: {},
						reviewable: {},
						editable: {}
					}
					{
						owned: u.owned(mdl).select([idcol, namecol]),
						visible: u.visible(mdl).select([idcol, namecol]),
						reviewable: u.reviewable(mdl).select([idcol, namecol]),
						editable: u.editable(mdl).select([idcol, namecol])
					}.each do |access_type, smpls|
						smpls.each do |s|
							all_samples[s.id] = s if all_samples[s.id].nil?
							ret[access_type][s.id] = s
						end
					end
					[u, ret]
				}]
				@acl = all_samples.map{|sid, s|
					rec = {
						id: sid,
						"#{mdl.name} ID" => sid,
						"#{mdl.name} Name" => s.name
					}
					users.each do |u|
						rec[u.name] = []
						rec[u.name] << "owned" unless users_to_samples[u][:owned][sid].nil?
						rec[u.name] << "visible" unless users_to_samples[u][:visible][sid].nil?
						rec[u.name] << "review" unless users_to_samples[u][:reviewable][sid].nil?
						rec[u.name] << "editable" unless users_to_samples[u][:editable][sid].nil?
					end
					rec
				}
				@coloring = Hash[users.map{|u|
					[u.name, {
						"owned" => "palegreen",
						"visible" => "PowderBlue",
						"review" => "lightyellow",
						"editable" => "lightsalmon"
					}]
				}]
				@coloring["#{mdl.name} Name"] = :factor
			end
		end
		
		
	end

	private

	def find_myself(userid)
		begin
			@user = User.find(userid)
		rescue ActiveRecord::RecordNotFound => e
			@user = User.find_by_name(userid)
		end
	end

end
