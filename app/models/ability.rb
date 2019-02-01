class Ability
	include CanCan::Ability
	def initialize(user)
		# Define abilities for the passed in user here. For example:
		#
		#   user ||= User.new # guest user (not logged in)
		#   if user.admin?
		#     can :manage, :all
		#   else
		#     can :read, :all
		#   end
		#
		# The first argument to `can` is the action you are giving the user
		# permission to do.
		# If you pass :manage it will apply to every action. Other common actions
		# here are :read, :create, :update and :destroy.
		#
		# The second argument is the resource the user can perform the action on.
		# If you pass :all it will apply to every resource. Otherwise pass a Ruby
		# class of the resource.
		#
		# The third argument is an optional hash of conditions to further filter the
		# objects.
		# For example, here the user can only update published articles.
		#
		#   can :update, Article, :published => true
		#
		# See the wiki for details:
		# https://github.com/CanCanCommunity/cancancan/wiki/Defining-Abilities
		
		## Tags
		can [:index, :show], Tag
		can [:edit, :update, :destroy], Tag do |tag|
			user.is_data_manager? 
		end
		can [:new, :create], Tag if user.is_data_manager? 
		
		### EXPERIMENTS
		can [:index], Experiment
		can [:new, :create], Experiment if user.is_data_manager? || user.is_research_manager? || user.is_admin?
		can [:edit, :update, :destroy], Experiment do |experiment|
			if experiment.id > 0 then
				user.is_data_manager? || user.is_research_manager? || user.is_admin?
				# user.can_edit?(experiment) || user.owns?(experiment) || user.is_admin?
				# only research and data manger should be able to modify a project - not normal users.
			else
				(user.id == (experiment.id / 100000.0).ceil * -1) || user.is_admin?
			end
		end
		can [:details, :more_details], Experiment
		can [:show, :aqua, :query_generator, :aqua_meta, :details, :more_details, :interactions, :interaction_details, :attribute_matrix, :panel_to_subject_matrix, :save_resultset], Experiment do |experiment|
			if experiment.id > 0 then
				experiment.users.include?(user) || user.can_review?(experiment) || user.is_admin?
			else # these are meta experiments...we need to check if the user is eligable to create or query this
				experiment.users.include?(user) || user.is_admin?
			end
		end
		
		## Entity Groups
		can [:index, :show_dataset_summary, :assign_entity], EntityGroup
		can [:new, :create], EntityGroup
		can [:batch_create], EntityGroup if user.is_admin? or user.is_data_manager?
		can [:show], EntityGroup do |eg|
			user.can_see?(eg) || user.can_review?(eg)
		end
		can [:edit, :update, :assign_entity], EntityGroup do |eg|
			user.can_edit?(eg) #|| user.can_review?(eg)
		end
		can [:destroy], EntityGroup do |eg|
			user.is_admin? || user.is_data_manager_at?(eg.institution)
		end
		
		## Entity
		can [:index, :assign_tags], Entity
		can [:new, :create], Entity
		can [:show], Entity do |entity|
			user.can_see?(entity) || user.can_review?(entity)
		end
		can [:edit, :update, :assign_specimen_probe, :assign_entity_group], Entity do |entity|
			user.can_edit?(entity) #|| user.can_review?(entity)
		end
		can [:destroy], Entity do |entity|
			user.is_admin? || user.is_data_manager_at?(entity.institution)
		end
		
		## SpecimenProbe
		can [:index, :assign_tags], SpecimenProbe
		can [:new, :create], SpecimenProbe
		can [:show], SpecimenProbe do |specimen_probe|
			user.can_see?(specimen_probe) || user.can_review?(specimen_probe)
		end
		can [:edit, :update, :assign_sample, :assign_entity], SpecimenProbe do |specimen_probe|
			user.can_edit?(specimen_probe) #|| user.can_review?(specimen_probe)
		end
		can [:destroy], SpecimenProbe do |specimen_probe|
			user.is_admin? || user.is_data_manager_at?(specimen_probe.institution)
		end

		### SAMPLES
		can [:index, :refreshindex, :sample_similarity, :gender_coefficient], Sample
		can [:assign_specimen, :refresh_stats], Sample if user.is_research_manager? or user.is_admin?
		can [:show, :detail], Sample do |sample|
			user.can_see?(sample) || user.can_review?(sample)
			# user.visible(Sample).include?(sample) || user.reviewable(Sample).include?(sample)
		end
		can [:edit, :update, :assign_specimen], Sample do |sample|
			user.can_edit?(sample)
			# user.editable(Sample).include?(sample)
		end
		can [:collectstats, :mass_destroy, :force_reload, :destroy], Sample do |sample|
			user.is_admin? || user.is_data_manager_at?(sample.institution)
		end
		# this part cannot have a blok, because there is no sample instance at the point of the evaluation
		can [:new, :create, :claimable, :refreshstats], Sample if user.is_admin?


		### VCF Files
		can [:index, :refreshindex, :baf_plot], VcfFile
		can [:create_sample_sheet, :download_sample_sheet, :assign_tags], VcfFile if user.is_data_manager? or user.is_admin?
		can [:mass_destroy], VcfFile if user.is_admin?
		can [:show, :download], VcfFile do |vcf|
			user.can_review?(vcf) # only data manager and research manager should be able to do that
			# user.can_see?(vcf) || user.can_review?(vcf)
			# user.visible(VcfFile).select("vcf_files.id").include?(vcf) || user.reviewable(VcfFile).select("vcf_files.id").include?(vcf)
		end
		can [:edit, :update, :destroy], VcfFile do |vcf|
			user.can_edit?(vcf) || user.is_data_manager_at?(vcf.institution)
			# user.editable(VcfFile).select("vcf_files.id").include?(vcf)
		end
		can [:aqua_annotate, :aqua_annotate_single], VcfFile do |vcf|
			user.is_admin? || user.is_data_manager_at?(vcf.institution)
			# user.editable(VcfFile).select("vcf_files.id").include?(vcf)
		end
		# this part cannot have a blok, because there is no sample instance at the point of the evaluation
		can [:new, :create, :batch_submit], VcfFile if user.is_data_manager? 
		

		### LongJobs
		can [:list, :index, :show, :status, :result], LongJob
		cannot [:new, :create, :edit, :update], LongJob
		can [:destroy, :clear_cache, :statistics], LongJob if user.is_admin?
		
		### Institutions
		can [:index, :show], Institution
		can [:new, :create, :edit, :update], Institution if user.is_admin?
		can [:destroy], Institution if user.is_admin?
		
		### Organisms
		can [:index, :show], Organism
		can [:new, :create, :edit, :update], Organism if user.is_admin?
		can [:destroy], Organism if user.is_admin?
		
		### SampleTag
		can [:index, :show], SampleTag
		can [:new, :create, :edit, :update], SampleTag if user.is_admin?
		can [:destroy], SampleTag if user.is_admin?
		
		### User
		can [:index, :access_control_list], User
		can [:show], User do |usr|
			usr.id == user.id || user.is_admin?
		end
		can [:new, :create, :edit, :update], User if user.is_admin?
		can [:destroy], User if user.is_admin?
		
		# GenericLists
		can [:index, :show], GenericList
		can [:new, :create], GenericList
		can [:edit, :update, :destroy], GenericList do |generic_list|
			generic_list.users.include?(user) || user.is_admin?
		end
		
		# Reports
		can [:index, :show, :download], Report
		can [:new, :create], Report
		can [:edit, :update, :destroy], Report do |report|
			report.user.id == user.id || user.is_admin?
		end
		
		### AQuA
		can (AquaController.action_methods - ApplicationController.action_methods).map(&:to_sym), Aqua
		can [:show_log], Aqua if user.is_admin?
		
	end
end
