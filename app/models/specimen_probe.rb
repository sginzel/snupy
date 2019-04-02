class SpecimenProbe < ActiveRecord::Base
		
	include SnupyAgain::Taggable

	belongs_to :entity
	has_many :samples, dependent: :nullify
	has_many :variation_calls, through: :samples

	has_one :institution, through: :entity
	has_one :entity_group, through: :entity
	has_many :users, through: :entity_group
	has_many :experiments, through: :entity_group
	
	has_one :organism, through: :entity
	has_many :vcf_files, through: :samples,
			 select: [:id, :contact, :filename, :md5checksum, :sample_names, :status, :institution_id, :name, :organism_id, :type, :filters, :updated_at, :created_at].map{|attr| "vcf_files.#{attr}"}
	
	### tags
	has_and_belongs_to_many :specimen_probe_tags, class_name: "Tag", join_table: :tag_has_objects, foreign_key: :object_id,
							:conditions => { "tags.object_type" => "SpecimenProbe"}
	has_many :entity_tags, class_name: "Tag", through: :entity
	has_many :sample_tags, class_name: "Tag", through: :samples, :uniq => true
	has_many :vcf_file_tags, class_name: "Tag", through: :vcf_files, :uniq => true
	
	
	validates :entity_id, presence: true, allow_blank: false
	validates :name, presence: true, allow_blank: false
	
	attr_accessible :name,
									:notes,
									:lab, :lab_contact,
									:internal_identifier, 
									:date_day, :date_month, :date_year, 
									:days_after_treatment, 
									:tumor_content, :tumor_content_notes, 
									:queryable, 
									:entity_id
	
	@relaxed_validation = false
	attr_accessor :relaxed_validation
	
	class SpecimenProbeTagValidator < ActiveModel::Validator
		def validate(record)
			begin
				raise "Name can't be emtpy" if record.name.to_s == ""
				raise "Entity can't be nil" if (record.entity_id.nil? or record.entity.nil?)

				entity = record.entity
				other_specs = entity.specimen_probes
				other_specs = other_specs.where("specimen_probes.id != #{record.id}") if record.persisted?
				other_specs = other_specs.pluck(:name).map(&:downcase)
				raise "Specimen with the same name exists for the entity." if other_specs.include?(record.name.downcase)

				# check tags
				if record.tags.size > 0 and !record.relaxed_validation then
					# Tissue and Status have to be set
					tag_classes = record.tags.map(&:category)
					if !(tag_classes.include?("TISSUE") && tag_classes.include?("STATUS")) then
						record.errors[:base] << "TISSUE AND STATUS tag are required to create a specimen"
					end
				else
					record.errors[:base] << "Can't create specimen without tags" unless record.relaxed_validation
				end
				# record.queryable = record.determine_queryable
				record.update_queryable
			rescue StandardError => e
				#pp "ERROR when validating SpecimenProbe ###############"
				#puts e.message
				#pp e.backtrace
				#pp "###############"
				record.errors[:base] << "VALIDATION FAILED: #{e.message}"
			end
			record.errors[:base]
		end
	end
	validates_with SpecimenProbeTagValidator
	
	def update_queryable
		# self.reload
		if !(self.entity_id.nil? or self.entity.nil?)
			self.entity.reload
			tag_categories = (self.tags + self.entity.tags).flatten.map(&:category).uniq
			classtag = self.entity.tags_by_category["CLASS"]
			return false if self.frozen? # this can happen when we try to destroy an entity group
			if classtag.nil? or classtag.size == 0 then
				self.queryable = false
			else
				if classtag.first.value == "shared control" then
					queryable_categories = ["STATUS", "TISSUE", "CLASS"]
				else
					queryable_categories = ["STATUS", "TISSUE", "DISEASE", "CLASS"]
				end
				self.queryable = queryable_categories.all?{|x| tag_categories.include?(x) }
			end
		else
			self.queryable = false
		end
		self.queryable
	end
	
	def queryable?
		queryable
	end
	
	def ready?
		queryable
	end
	
	def to_s
		"[Specimen-#{name}]"
	end
	
	def baf(varids = nil)
		varids = self.samples.variation_calls.pluck(:variation_id).uniq if varids.nil?
		varids = [varids] unless varids.is_a?(Array)
		bafs = self.variation_calls.where(variation_id: varids).pluck("alt_reads/(alt_reads+ref_reads)").map(&:to_f)
		return bafs.first if varids.size == 1
		bafs
	end
	
	def self.create_from_template(templates, entity = nil)
		created_specimen = []
		(templates || []).each do |idx, template|
			next if template[:name].to_s == ""
			mytags = {}
			if !template[:tags].nil? then
				Tag.find(template[:tags].values.flatten.reject{|id| id.to_s == ""}).each do |tag|
					mytags[tag.category] = [] if mytags[tag.category].nil?
					mytags[tag.category] << tag
				end
				template.delete(:tags)
			end
			
			samples = []
			if !template[:samples].nil? then
				samples = Sample.find(template[:samples].values.flatten.reject{|id| id.to_s == ""})
				template.delete(:samples)
			end
			
			specimen = SpecimenProbe.new(template.merge({entity_id: entity.id}))
			specimen.samples = samples
			specimen.tags = mytags.values.flatten
			if (specimen.save) then
				created_specimen << {label: "Created #{specimen.name} and linked with #{entity.name}", category: "success", name: specimen.name, specimen: specimen}
			else
				created_specimen << {label: "Could not be saved. Reason: #{specimen.errors.messages[:base]}. Template: #{template.pretty_inspect}", category: "error", name: specimen.name, specimen: nil}
			end
		end
		created_specimen
	end

end
