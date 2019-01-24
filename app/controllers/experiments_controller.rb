class ExperimentsController < ApplicationController
	include ApplicationHelper
	include ExperimentsAquaHelper
	include ExperimentsAquaHelperGeneMatrix
	include ExperimentsQueryGeneratorHelper
	include ExperimentResultSetHelper
	before_filter :admin_required, :only => [ :delete, :destroy ]
	before_filter :access_required

	# GET /experiments
	# GET /experiments.json
	def index
		@experiments = current_user.visible(Experiment)
		@experiments = filter_collection @experiments, [:name, :title, :description], 100
		@experiments = Experiment.where(id: @experiments.pluck(:id)).includes([:institution, :users])
		
		#if current_user().is_admin then
		#	@experiments = Experiment.all
		#else
		#	@experiments = current_user().experiments.where("experiments.id > 0")
		#end
		respond_to do |format|
			format.html # index.html.erb
			format.json { render json: @experiments,
			                     :include => {
				                     users: {:only => [:id, :name],
				                             :except => [:created_at, :updated_at]},
				                     samples: {:only => [:id, :status, :name, :vcf_file_id, :vcf_sample_name, :specimen_probe_id, :entity_id, :entity_group_id],
				                               :except => [:created_at, :updated_at]},
				                     entity_groups: {:only => [:id, :name],
				                               :except => [:created_at, :updated_at]},
				                     institution: {:only => [:id, :name],
				                                :except => [:created_at, :updated_at]},
			                     }
			}#=> {:only => [:id, :name}}, :except => [:created_at, :updated_at] }
		end
	end

	# GET /experiments/1
	# GET /experiments/1.json
	def show
		if params[:id].to_i.to_s == params[:id].to_s then
			@experiment = Experiment.find(params[:id])
		else
			@experiment = Experiment.find_by_name(params[:id])
			if !@experiment.nil? then
				redirect_to action: "show", id: @experiment.id
			else
				alert_and_back_or_redirect(message = "Project #{params[:id]} not found", url = "/experiments")
			end
			return true
		end
		
		respond_to do |format|
			format.html # show.html.erb
			format.json { render json: @experiment,
			                     :include => {
									users: {:only => [:id, :name],
									        :except => [:created_at, :updated_at]},
									samples: {:only => [:id, :status, :name, :vcf_file_id, :vcf_sample_name, :specimen_probe_id, :entity_id, :entity_group_id],
									          :except => [:created_at, :updated_at]},
									entity_groups: {:only => [:id, :name],
									                :except => [:created_at, :updated_at]},
									institution: {:only => [:id, :name],
									              :except => [:created_at, :updated_at]}
			                     }
			}
		end
	end

	# GET /experiments/new
	# GET /experiments/new.json
	def new
		@experiment = Experiment.new
		@users = User.all
		@institutions = Institution.all
		@entity_groups = current_user.reviewable(EntityGroup).includes(:institution)
		@samples = current_user.reviewable(Sample)

		respond_to do |format|
			format.html # new.html.erb
			format.json { render json: @experiment }
		end
	end

	# GET /experiments/1/edit
	def edit
		@experiment = Experiment.find(params[:id])
		@users = User.all
		@institutions = Institution.all
		@samples = (current_user.reviewable(Sample) + @experiment.samples).uniq
		@entity_groups = current_user.reviewable(EntityGroup)
	end

	# POST /experiments
	# POST /experiments.json
	def create
		@experiment = Experiment.new(params[:experiment])
		@users = User.find_all_by_id(params[:users])
		@users = (@users + [current_user]).uniq
		@entity_groups = current_user.reviewable(EntityGroup).find(params[:entity_groups] || [])

		# make sure only samples that the user has access to will be added to the experiment
		@samples = current_user.reviewable(Sample).includes(:users)
		.where("samples.id" => (params[:samples] || []))
		
		#@samples = [] if @samples.nil?
		
		if (params[:samples] || []).size != @samples.size
			@experiment.errors[:base] = "Access denied to some of the given samples."
		end

		@experiment.users = @users
		@experiment.entity_groups = @entity_groups
		@experiment.samples = @samples

		## We need to first save the experiment so it get persisted and gets an ID
		## after that we have to set the users and samples field and save the experiment again
		## so that the validations on the experiment model can verify the consistency of the samples
		## if we set the samples before the experiment object is persisted we have no access to the
		## samples during the validation process. This problem is known for has_and_belongs_to_many
		## relations. There is gem called deferred_associations but it turned out not to work
		respond_to do |format|
			if @experiment.save
				format.html { redirect_to @experiment, notice: 'Experiment was successfully created.' }
				format.json { render json: @experiment, status: :created, location: @experiment }
			else
				format.html { render action: "new" }
				format.json { render json: @experiment.errors, status: :unprocessable_entity }
			end
		end
	end

	# PUT /experiments/1
	# PUT /experiments/1.json
	def update
		@experiment = Experiment.find(params[:id])

		@users = User.find_all_by_id(params[:users])
		@users = (@users + [current_user]).uniq

		@samples = current_user.reviewable(Sample).includes(:users)
		.where("samples.id" => (params[:samples] || []))
		@entity_groups = current_user.reviewable(EntityGroup).find(params[:entity_groups] || [])
		
		@experiment.users = @users
		@experiment.entity_groups = @entity_groups
		@experiment.samples = @samples

		@institutions = Institution.all

		respond_to do |format|
			if @experiment.update_attributes(params[:experiment])
				format.html { redirect_to @experiment, notice: 'Experiment was successfully updated.' }
				format.json { head :no_content }
			else
				format.html { render action: "edit" }
				format.json { render json: @experiment.errors, status: :unprocessable_entity }
			end
		end
	end

	# DELETE /experiments/1
	# DELETE /experiments/1.jsonjoins
	def destroy
		@experiment = Experiment.find(params[:id])
		@experiment.destroy

		respond_to do |format|
			format.html { redirect_to experiments_url }
			format.json { head :no_content }
		end
	end
	



end
