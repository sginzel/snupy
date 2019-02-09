# == Description
# Variations are a key component of this system. They are defined by a Region and an Alteration
# and are very flexible. 
# == Attributes
# This variation has no attributes by itself. It just references other objects.
# == References
# * Region
# * Alteration
# * VariationTag
# * VariationCall
class Variation < ActiveRecord::Base
	
	include SnupyAgain::ModelUtils
	
	belongs_to :region, inverse_of: :variations
	belongs_to :alteration, inverse_of: :variations
	# has_one :regions, through: :variations, inverse_of: :variation
	# has_one :alterations, through: :variations, inverse_of: :variation
	has_and_belongs_to_many :variation_tags, join_table: :variation_has_variation_tag
	
	has_many :samples, through: :variation_calls, inverse_of: :variations
	has_many :vcf_files, through: :samples, inverse_of: :variations, :uniq => true,
			 select: [:id, :contact, :filename, :md5checksum, :sample_names, :status, :institution_id, :name, :organism_id, :type, :filters, :updated_at, :created_at].map{|attr| "vcf_files.#{attr}"}
	has_many :specimen_probes, through: :samples, :uniq => true
	has_many :entities, through: :samples, :uniq => true
	has_many :entity_groups, through: :samples, :uniq => true
	
	has_many :entity_group_tags, through: :entity_groups, :uniq => true
	has_many :entity_tags, through: :entities, :uniq => true
	has_many :specimen_probe_tags, through: :specimen_probes, :uniq => true
	has_many :sample_tags, through: :samples, :uniq => true
	has_many :vcf_file_tags, through: :vcf_files, :uniq => true
	
	
	has_many :variation_calls, inverse_of: :variation, dependent: :destroy
	#has_many :variation_annotations, inverse_of: :variation, dependent: :destroy
	#has_many :genetic_elements, through: :variation_annotations, inverse_of: :variations
	#has_many :organisms, through: :variation_annotations, inverse_of: :variations
	#has_many :consequences, through: :variation_annotations, inverse_of: :variations
	has_many :users, through: :samples
	has_many :experiments, through: :samples, inverse_of: :variations
	has_many :organisms, through: :vcf_files, inverse_of: :variations
	
	has_many :variation_statistics, dependent: :delete_all, foreign_key: :record_id, inverse_of: :variation
	
	
	attr_accessible :region_id, :alteration_id
	
	scope :full, joins(:region, :alteration).includes(:region, :alteration)
	
	def tags
		return variation_tags
	end
	
	def tags=(newval)
		return variation_tags = newval
	end
	
	def statistics
		SampleStatistic.where(type: "SampleStatistic", record_id: self.id)
	end
	
	def coordinates
		"#{self.region.name}:#{self.region.start}-#{self.region.stop}#{self.alteration.ref}>#{self.alteration.alt}"
	end
	
	# This method returns only genetic elements that are hit by a sequence altering variation  
	#  def self.affected_genetic_elements(variations, organsim, consequences = Consequence::FATAL)
	#		vas = VariationAnnotation.joins(:consequences)
	#		                    .includes(:consequences, :genetic_element)
	#		                    .where("variation_id" => variations)
	#		                    .where("consequences.consequence" => consequences)
	#		                    .where(organism_id: organsim)
	#		vas.map(&:genetic_element)
	#  end

end
