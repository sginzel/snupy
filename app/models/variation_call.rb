# == Description
# A VariationCall connect a Variation with a Sample and as such has different properties, like the read depth etc.
# The minimal set of attributes is directly associated with a VariationCall, 
# these properties resemble the standard properties of a VCF record in the 
# VCF4.1 format description. Additional attributes for a single VariationCall 
# can be added through VariationCallTags. This also means that - if desired -
# VariationCalls can share the same attribute.
 
# == Attributes (see VCF4.1 format description)
# [dp] Read Depth of Variation
# [filter] Filter value. PASS if passed, some else otherwise
# [gl] Genotype Likelihood
# [gq] Genotype Quality
# [gt] Genotype (0/1, 1/1, 1/2 for unphased, 0|1, 1|0, 1|1, 1|2 for phased genotype)
# [ps] Phase Set
# [qual] Variation Quality Value
class VariationCall < ActiveRecord::Base
	
  belongs_to :sample, inverse_of: :variation_calls
  has_one :organism, through: :sample, inverse_of: :variation_calls
  has_one :vcf_file, through: :sample, inverse_of: :variation_calls
  belongs_to :variation, inverse_of: :variation_calls
  #has_many :variation_annotations, foreign_key: :variation_id, primary_key: :variation_id, inverse_of: :variation_calls
  
  # has_many :variation_annotations, through: :variation
  has_one :region, through: :variation
  has_one :alteration, through: :variation
  has_and_belongs_to_many :variation_call_tags, join_table: :variation_call_has_variation_call_tag
  
  has_many :users, through: :sample
  has_many :experiments, through: :sample, inverse_of: :variations

  has_one :specimen_probe, through: :sample
  has_one :entity, through: :specimen_probe
  has_one :entity_group, through: :entity
  
  attr_accessible :dp, :filter, :gl, :gq, :gt, :ps, :qual, :variation_id, :sample_id, :sample, :ref_reads, :alt_reads, :cn, :cnl, :fs
  
  scope :full, joins(:variation, :sample)
  #scope :va, joins(:variation, :variation_annotations, :sample, :organism)
  #					 .where("vcf_files.organism_id = variation_annotations.organism_id")
  
  def tags
  	return variation_call_tags
  end 
  
  def tags=(newval)
  	return variation_call_tags = newval
  end

#	def genetic_elements
#		VariationCall.genetic_elements(self.id, self.organism)
#	end
	
#	def self.genetic_elements(ids, organism)
#		organism = Organism.find(organism) unless organism.is_a?(Organism)
#		geids = VariationAnnotation
#			.joins(:variation_calls)
#			.where(organism_id: organism.id)
#			.where("variation_calls.id" => ids)
#			.pluck(:genetic_element_id)
#		if geids.size > 0 then
#			GeneticElement.where(id: geids)
#		else
#			GeneticElement.where(" 1 = 0 ") # make it impossible to get anything
#		end
#	end
	
	def <=> (other_variation_call)
		ret = self.region <=> other_variation_call.region
		if ret == 0 then
			ret = self.alteration <=> other_variation_call.alteration
			if ret == 0 then
				ret = self.sample_id <=> other_variation_call.sample_id
			end
		end
		return ret
	end
	
	def baf
		return nil if self.ref_reads < 0 or self.alt_reads < 0
		self.alt_reads.to_f/(self.alt_reads+self.ref_reads)
	end
  
end
