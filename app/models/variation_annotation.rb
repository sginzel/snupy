# == Description
# == Attributes
# [amino_acids] Amino acid change
# [blosum62] Blosum Exchange score of Amino Acid
# [canonical] ?
# [cds] CDS Identifier
# [cdna_position] Positoin in CDNA
# [cds_position] CDS Position
# [codons] Codon Change
# [distance] Distance of variation to feature
# [domains] affeceted domaain
# [downstreamprotein] downstream protein change
# [existing_variation] existing variation at this site
# [exon] Which exon is hit? (e.g. 7/9)
# [gmaf] global minor allele frequency
# [hgvsc] Human Genome Variation SC
# [hgvsp] Human Genome Variation SP
# [intron] Which intron is hit?(e.g. 6/13)
# [mofif_name] Motif
# [motif_pos] Hit relative to motif
# [other_yaml] Extendable YAML column
# [polyphen_score] LOFPT PolyPhen2 score
# [protein_position] Position of Variation in Protein
# [proteinlenghtchange] Possible length change of protein
# [sift_score] # LOFPT SIFT score.
# [sv] StructuralVariation
# == References
# * Variation
# * LossOfFunction
# * Consequence
class VariationAnnotation < ActiveRecord::Base
	
	include SnupyAgain::ModelUtils
	
	belongs_to :variation#, inverse_of: :variation_annotations
	has_one :alteration, through: :variation#, inverse_of: :variation_annotations
	has_one :region, through: :variation#, inverse_of: :variation_annotations
	belongs_to :genetic_element, inverse_of: :variation_annotations
	belongs_to :loss_of_function, inverse_of: :variation_annotations
	belongs_to :organism, inverse_of: :variation_annotations
	has_and_belongs_to_many :consequences, join_table: :variation_annotation_has_consequence #, inverse_of: :variation_annotations
	# has_one :variation, inverse_of: :variation_annotations
	# has_many :variation_calls, through: :variation, inverse_of: :variation_annotations
	has_many :variation_calls, foreign_key: :variation_id, primary_key: :variation_id, inverse_of: :variation_annotations
	has_many :samples, through: :variation_calls, inverse_of: :variation_annotations

	has_many :users, through: :samples
	has_many :experiments, through: :samples, inverse_of: :variation_annotations

	attr_accessible :amino_acids, :blosum62, :canonical, :ccds, :cdna_position, :cds_position, :codons, :distance, :domains, :downstreamprotein, :existing_variation, :exon, :gmaf, :hgvsc, :hgvsp, :intron, :mofif_name, :motif_pos, :other_yaml, :polyphen_score, :protein_position, :proteinlenghtchange, :sift_score, :sv, :motif_name, :proteinlengthchange, :global_pop_freq, :high_inf_pos, :motif_score_change, :has_consequence

	before_destroy {|record| record.consequences = [] }

	scope :full, joins(:variation, :genetic_element).includes(:variation, :genetic_element, :loss_of_function)

	def self.variation_annotation_scoped(organism_id, smplids = [], variation_ids = [])
		ret = VariationAnnotation
											 .joins(variation: [:variation_calls, :region, :alteration])
											 .joins(:genetic_element, :loss_of_function, :organism)
											 .where("variation_annotations.organism_id" => organism_id)
		ret = 					ret.where("variations.id" => variation_ids) if variation_ids.size > 0
		ret = 					ret.where("variation_calls.sample_id" => smplids) if smplids.size > 0
	 	ret.includes(:genetic_element, :loss_of_function)
	end
	
end
