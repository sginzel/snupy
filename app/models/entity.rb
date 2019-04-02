class Entity < ActiveRecord::Base
	include SnupyAgain::Taggable

	#belongs_to :institution
	belongs_to :entity_group
	has_one :institution, through: :entity_group
	has_many :users, through: :entity_group
	
	has_one :organism, through: :entity_group 
	has_many :experiments, through: :entity_group
	has_many :specimen_probes, class_name: "SpecimenProbe", dependent: :destroy
	has_many :samples, through: :specimen_probes
	has_many :vcf_files, through: :samples,
			 select: [:id, :contact, :filename, :md5checksum, :sample_names, :status, :institution_id, :name, :organism_id, :type, :filters, :updated_at, :created_at].map{|attr| "vcf_files.#{attr}"}

	has_many :variation_calls, through: :specimen_probes
	
	has_many :variations, through: :variation_calls
	
	has_and_belongs_to_many :entity_tags, class_name: "Tag", join_table: :tag_has_objects, foreign_key: :object_id,
							:conditions => { "tags.object_type" => "Entity"}
	has_many :specimen_probe_tags, class_name: "Tag", through: :specimen_probes, :uniq => true
	has_many :sample_tags, class_name: "Tag", through: :samples, :uniq => true
	has_many :vcf_file_tags, class_name: "Tag", through: :vcf_files, :uniq => true
	# has_many :users, through: :institution

	attr_accessible :name, :nickname, :internal_identifier, :date_first_diagnosis, 
									:family_members_available, :notes, :entity_group_id, :contact
	
	validates :name, presence: true, allow_blank: false
	validates :entity_group_id, presence: true, allow_blank: false
	
	validates_associated :specimen_probes
	
	#after_commit :update_query_status
	#after_rollback :update_query_status
	after_save :update_query_status
	after_update :update_query_status
	
	@relaxed_validation = false
	attr_accessor :relaxed_validation
	
	class EntityTagValidator < ActiveModel::Validator
		def validate(record)
			begin
				raise "Name can't be emtpy" if record.name.to_s == ""
				
				other_ents = record.entity_group.entities
				other_ents = other_ents.where("entities.id != #{record.id}") if record.persisted?
				other_ents = other_ents.pluck(:name).map(&:downcase)
				raise "Entity with the same name exists for the entity group" if other_ents.include?(record.name.downcase) and !record.relaxed_validation
				
				# check tags
				if record.tags.size > 0 and !record.relaxed_validation then
					# find class tag
					class_tags = record.tags.select{|t| t.category.upcase == "CLASS"}
					if class_tags.size > 0 then
						has_control_tag = class_tags.select{|t| t.value.to_s.downcase == "shared control"}.size > 0
						# if this entity is not a shared control, we require a disease to be set
						if !has_control_tag then
							disease_tags = record.tags.select{|t| t.category.upcase == "DISEASE"}
							if disease_tags.size == 0 then
								record.errors[:base] << "DISEASE tag is required for all non 'shared control' entites"
							end
						end
					else
						record.errors[:base] << "CLASS tag is required to create an entity" unless record.relaxed_validation
					end
				else
					record.errors[:base] << "Can't create entity without tags" unless record.relaxed_validation
				end
			rescue StandardError => e
				record.errors[:base] << "Could not save Entity (#{e.message})"
			end
			record.errors[:base]
		end
	end
	validates_with EntityTagValidator

	def update_query_status
		self.specimen_probes.all? do |specimen|
			specimen.entity.reload
			specimen.update_queryable
			specimen.save!
		end
	end
	
	def parents()
		# check if I am a control entity
		#status = self.specimen_probes.joins(:tags).where("tags.category" => "STATUS").pluck("tags.value")
		#return [] if status.any?{|s| s =~ /^C.*/}
		ent_ids = self.entity_group.specimen_probes.joins(:tags).where("tags.value"=> ["CFFTHR", "CFMTHR"]).pluck(:entity_id)
		Entity.where(id: ent_ids-[self.id])
	end
	
	def father
		ent_ids = self.entity_group.specimen_probes.joins(:tags).where("tags.value"=> ["CFFTHR"]).pluck(:entity_id)
		Entity.where(id: ent_ids-[self.id])
	end
	
	def mother
		ent_ids = self.entity_group.specimen_probes.joins(:tags).where("tags.value"=> ["CFMTHR"]).pluck(:entity_id)
		Entity.where(id: ent_ids-[self.id])
	end
	
	def siblings()
		# check if I am a control entity
		#status = self.specimen_probes.joins(:tags).where("tags.category" => "STATUS").pluck("tags.value")
		#return [] if status.any?{|s| s =~ /^C.*/}
		ent_ids = self.entity_group.specimen_probes.joins(:tags).where("tags.value"=> ["CFSSTR", "CFBRTHR"]).pluck(:entity_id)
		Entity.where(id: ent_ids-[self.id])
	end
	
	def baf(varids = nil)
		Hash[specimen_probes.map{|spec|
			[spec, spec.baf(varids)]
		}]
	end
	
	def self.create_from_template(templates, entity_group = nil)
		created_entities = []
		(templates || []).each do |idx, template|
			next if template[:name].to_s == ""
			# check CLASS and disease tag
			mytags = []
			if !template[:tags].nil? then
				mytags = Tag.find(template[:tags].values.flatten.reject{|id| id.to_s == ""})
				template.delete(:tags)
			end
			entity = Entity.new(template.merge({entity_group_id: entity_group.id}))
			entity.tags = mytags
			if (entity.save) then
				created_entities << {label: "Created #{entity.name} with links to #{entity_group.name}", category: "success", name: entity.name, entity: entity}
			else
				created_entities << {label: "Entity could not be saved. Reason: #{(entity.errors.messages[:base] || ["No reason."].join(" / "))}. Template: #{template.pretty_inspect}", category: "error", name: template[:name], entity: nil}
			end
			
		end
		created_entities
	end
	
	# Input: list of variation call ids
	# output: {varid: "0/1"}
	# INfo: COnflicting genotypes will be returned as "1/1"
	def genotypes(varcall_ids = nil)
		varcall_ids = self.variation_call_ids if varcall_ids.nil?
		genotype_normalization_map = {
			"0/1" => "0/1",
			"1/0" => "0/1",
			"1/1" => "1/1",
			"0|1" => "0/1",
			"1|0" => "0/1",
			"1|1" => "1/1",
			"1/2" => "0/1",
			"2/1" => "0/1",
			"1|2" => "0/1",
			"2|1" => "0/1"
		}
		ret = VariationCall.where(id: varcall_ids).where(sample_id: self.samples).select([:variation_id, :gt]).group_by(&:variation_id).with_indifferent_access
		ret.keys.each do |varid|
			if ret[varid].size > 1
				ret[varid] = :"1/1"
			else
				ret[varid] = ret[varid].first.gt.to_sym
			end
		end
		ret
	end
	
	# Input: list of variatino call ids
	# output: {varid: "Y|N|?"}
	def autosomal_dominant(varcall_ids = nil)
		varcall_ids = self.variation_call_ids if varcall_ids.nil?
		#fathergt = (self.father.first || Entity.new()).genotypes
		#mothergt = (self.mother.first || Entity.new()).genotypes
		affected = (self.parents.joins(:tags).where("tags.category" => "DISEASE"))
		myself = self.genotypes
		if affected.size == 0 then
			return Hash[myself.keys.map{|varid| [varid, :N]}]
		end
		not_affteced = (self.parents) - affected
		
		affectedgt = {}
		not_affectedgt = {}
		affected.each do |ent|
			ent.genotypes.each do |varid, gt|
				affectedgt[varid] = gt if affectedgt[varid].nil? || gt == :"1/1"
			end
		end
		not_affteced.each do |ent|
			ent.genotypes.each do |varid, gt|
				not_affectedgt[varid] = gt if not_affectedgt[varid].nil? || gt == :"1/1"
			end
		end
		
		is_not_autosomal = Variation.joins(:region)
			                   .where("variations.id" => myself.keys)
			                   .select(["variations.id", "regions.name IN ('X', 'Y') AS is_not_autosomal"]).group_by(&:id)
		result = Hash[myself.keys.map{|varid| [varid, :N]}]
		((myself.keys & affectedgt.keys)-not_affectedgt.keys).each do |varid|
			if is_not_autosomal[varid].first.is_not_autosomal == 0 then
				result[varid] = :Y
			else
				result[varid] = :xy
			end
		end
		result
	end
	
	# Input: list of variatino call ids
	# output: {varid: "Y|N|?"}
	def autosomal_recessive(varcall_ids = nil)
		varcall_ids = self.variation_call_ids if varcall_ids.nil?
		fathergt = (self.father.first || Entity.new()).genotypes
		mothergt = (self.mother.first || Entity.new()).genotypes
		myself = self.genotypes
		is_not_autosomal = Variation.joins(:region)
			               .where("variations.id" => myself.keys)
			               .select(["variations.id", "regions.name IN ('X', 'Y') AS is_not_autosomal"]).group_by(&:id)
		myself.keys.each do |varid|
			if is_not_autosomal[varid].first.is_not_autosomal == 1 then
				myself[varid] = :N
			else
				fgt = fathergt[varid] || :"?"
				mgt = mothergt[varid] || :"?"
				if (fgt == :"0/1" && mgt == :"0/1") &&
					myself[varid] == :"1/1" then
					myself[varid] = :Y
				elsif (fgt == :"?" || mgt == :"?") &&
					myself[varid] == :"1/1" then
					myself[varid] = :"?"
				else
					myself[varid] = :N
				end
			end
			
		end
		myself
	end
	
	# Input: list of variatino call ids
	# output: {varid: "Y|N|?"}
	def denovo(varcall_ids = nil)
		varcall_ids = self.variation_call_ids if varcall_ids.nil?
		fathergt = (self.father.first || Entity.new()).genotypes
		mothergt = (self.mother.first || Entity.new()).genotypes
		myself = self.genotypes
		myself.keys.each do |varid|
			myself[varid] = :N
		end
		(myself.keys - (fathergt.keys|mothergt.keys) || []).each do |varid|
			myself[varid] = :Y
		end
		myself
	end
	
	# Input: list of variatino call ids and a scope to retrieve transcripts
	# output: {varid: "Y|N|?"}
	def compound_heterozygous(varcall_ids = nil, transcript_scope = Vep::Ensembl.where(canonical: 1, consequence: Vep.DEFAULT_CONSEQUENCES), transcript_attribute = :transcript_id)
		varcall_ids = self.variation_call_ids if varcall_ids.nil?
		
		# get the variations
		varids = VariationCall.where(sample_id: self.samples).uniq(:variation_id).pluck(:variation_id)
		trans2vars = transcript_scope
			                   .where(organism_id: self.organism)
			                   .where(variation_id: varids)
			                   .select([:variation_id, transcript_attribute])
			                   .group_by{|annot| annot[transcript_attribute]}
		trans2vars.keys.each do |trans|
			trans2vars[trans] = trans2vars[trans].map(&:variation_id)
		end
		
		fathergt = (self.father.first || Entity.new()).genotypes
		mothergt = (self.mother.first || Entity.new()).genotypes
		myself = self.genotypes
		
		result = {}
		myself.keys.each do |varid|
			result[varid] = nil
		end
		
		trans2vars.each do |transcript, varids|
			# check if any of the variants occur in father/mother
			fvarids = varids.reject{|varid| fathergt[varid].nil?}
			mvarids = varids.reject{|varid| mothergt[varid].nil?}
			from_father = (fvarids - mvarids)
			from_mother = (mvarids - fvarids)
			if from_father.size >= 1 && from_mother.size >= 1 then
				(from_father|from_mother).each do |varid_hit|
					result[varid_hit] = transcript
				end
			end
		end
		result
	end
	
end
