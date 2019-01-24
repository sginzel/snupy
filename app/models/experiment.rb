# == Description
# An Experiment belongs to a institution and is accessible by differnt users.
# It also consists of different Sample which can be added and removed by the user, if he has access to the samples.
# == Attributes
# [concact] Contact person for this experiment
# [description] short description
# [name] A name for the experiment, may be long
# [title] short title for the experiment
# [institution] Institution
# [institution_id] Institution
class Experiment < ActiveRecord::Base
	
	has_and_belongs_to_many :users, join_table: :experiment_has_user
	has_and_belongs_to_many :long_jobs, join_table: :experiment_has_long_jobs
	
	has_and_belongs_to_many :entity_groups, join_table: :experiment_has_entity_groups
	has_many :entities, through: :entity_groups #, class_name: "Entity"
	has_many :specimen_probes, through: :entities
	# has_many :samples, through: :specimen_probes
	has_and_belongs_to_many_with_deferred_save :samples, join_table: :sample_has_experiments
	
	belongs_to :institution
	
	has_many :variation_calls, through: :samples, inverse_of: :experiments
	has_many :variations, through: :samples, inverse_of: :experiments
	#has_many :variation_annotations, through: :samples, inverse_of: :experiments
	#has_many :genetic_elements, through: :variation_annotations, inverse_of: :experiments
	#has_many :consequences, through: :variation_annotations, inverse_of: :experiments
	
	attr_accessible :id, :contact, :description, :name, :title, :institution_id, :institution
	
	validates :institution_id, presence: true, allow_blank: false
	
	before_destroy :destroy_has_and_belongs_to_many_relations
	
	# == Description
	# This Validator checks if all selected samples of the experiment belong to the same organism
	# If it doesnt we delete all associations between the experiment and the samples
	# The user can then choose again from the previously selected samples in the edit Mask. 
	class ExperimentValidator < ActiveModel::Validator
		def validate(record)
			if record.samples.size > 0 then
				organism_ids = record.samples.joins(:vcf_file).uniq.pluck("vcf_files.organism_id")
				if organism_ids.size > 1
					record.samples = []
					organism_names = Organism.where(id: organism_ids).pluck(:name)
					record.errors[:base] << "You may only choose samples with the same organism, but you choosed from (#{organism_names.join(",")})."
					Rails.logger.warn "[EXPERIMENT] User wants to create an experiment with different organisms"
				end
			end
			# lets make sure the updated_at field is updated each time for this type
			record.update_attribute(:updated_at, Time.now)
		end
	end
	
	validates_with ExperimentValidator
	
	def organism_id
		organism_ids = samples.joins(:organism).uniq.pluck(:organism_id)
		# organism_ids = samples.joins(:organism).uniq.pluck("entity_groups.organism_id")
		raise "Experiment ##{self.id} is associated to more than one organism. This must not happen." if organism_ids.size > 1
		if organism_ids.size > 0 then
			return organism_ids.first
		else
			return nil
		end
	end
	
	def organism
		oid = organism_id()
		return nil if oid.nil?
		Organism.find(organism_id)
	end
	
	def destroy_has_and_belongs_to_many_relations
		# users.delete
		# samples.delete
		self.users   = []
		self.samples = []
		self.long_jobs.delete_all
		self.long_jobs     = []
		self.entity_groups = []
	end
	
	def query_aqua(opts, binding = nil)
		qp                 = AquaQueryProcess.new(self.id, binding)
		varcallids         = (qp.start(opts) || []).uniq
		@query_result_size = varcallids.size
		AquaResult.new((varcallids || [])) # return a AquaResult Object - this one uses compressions for the variation call ids to save memory.
	end
	
	# this is the callback function of the long job which we can use to indicate how big the result will be.
	def after(job)
		long_job = LongJob.find_by_delayed_job_id(job.id)
		long_job.update_attribute("title", "[##{@query_result_size || -1}] " + long_job.title)
	end
	
	# Execute a query on this experiment
	def query(opts = {})
		qp  = SnupyAgain::QueryProcess::QueryProcess.new()
		ret = qp.process_query(self, opts)
		ret
	end
	
	def create_query_result(varcalls, attributes)
		SnupyAgain::QueryProcess::QueryProcess.new()
			.create_query_result(varcalls, attributes)
	end
	
	def self.get_meta_experiment_id(user, organism)
		(user.id * -100000) - organism.id
	end
	
	def self.meta_experiment_for(user, organism, refresh_samples = false)
		metaexpid = get_meta_experiment_id(user, organism)
		if user.experiments.where("experiments.id" => metaexpid).first.nil? then
			experiment = Experiment.new({
											id:             metaexpid,
											name:           "Meta Project for #{user.name}",
											title:          "#{organism.name}",
											description:    "Automatically generated project",
											institution_id: user.institutions.first.id,
											contact:        user.full_name
										})
			experiment.save
			experiment.users << user
			experiment.samples = user.reviewable(Sample).joins(:vcf_file_nodata).where("vcf_files.organism_id" => organism.id)
			experiment.save
		else
			experiment = Experiment.find(metaexpid)
			if refresh_samples then
				newsmpls = user.reviewable(Sample).joins(:vcf_file_nodata).where("vcf_files.organism_id" => organism.id)
				if (experiment.samples & newsmpls).size != newsmpls.size
					experiment.long_jobs.delete_all
					experiment.long_jobs = []
					experiment.samples   = newsmpls #user.reviewable(Sample).joins(:vcf_file_nodata).where("vcf_files.organism_id" => organism.id)
				end
			end
			experiment.updated_at = Time.now
			experiment.save
		end
		experiment
	end

	# find all sampleids that are directly associated with the experiment
	# or associated through its entity groups
	def associated_sample_ids
		smpls = (self.sample_ids || [])
		ent_smpls = Experiment.includes(:entity_groups => :samples).where("experiments.id" => self.id)
										.map(&:entity_groups).flatten.map(&:samples).flatten.map(&:id)
		(smpls + ent_smpls).flatten.uniq.sort
	end

	def associated_samples
		Sample.where(id: associated_sample_ids)
	end

end
