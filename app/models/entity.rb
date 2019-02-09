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
		Entity.where(id: ent_ids)
	end
	
	def father
		ent_ids = self.entity_group.specimen_probes.joins(:tags).where("tags.value"=> ["CFFTHR"]).pluck(:entity_id)
		Entity.where(id: ent_ids)
	end
	
	def mother
		ent_ids = self.entity_group.specimen_probes.joins(:tags).where("tags.value"=> ["CFMTHR"]).pluck(:entity_id)
		Entity.where(id: ent_ids)
	end
	
	def siblings()
		# check if I am a control entity
		#status = self.specimen_probes.joins(:tags).where("tags.category" => "STATUS").pluck("tags.value")
		#return [] if status.any?{|s| s =~ /^C.*/}
		ent_ids = self.entity_group.specimen_probes.joins(:tags).where("tags.value"=> ["CFSSTR", "CFBRTHR"]).pluck(:entity_id)
		Entity.where(id: ent_ids)
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
	
end
