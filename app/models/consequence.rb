# == Description
# Contains the consequences of a VEP run. These should correspond to SequenceOntology (SO) terms.
class Consequence < ActiveRecord::Base
	
	NOT_INTERESTING = %w(5_prime_UTR_variant 3_prime_UTR_variant intron_variant upstream_gene_variant downstream_gene_variant intergenic_variant)
										.map(&:upcase)
	
	FATAL = %w(missense_variant inframe_deletion inframe_insertion TF_binding_site_variant stop_lost stop_gained splice_donor_variant splice_acceptor_variant frameshift_variant mature_miRNA_variant incomplete_terminal_codon_variant TFBS_ablation)
	
  attr_accessible :consequence
  has_and_belongs_to_many :variation_annotations, join_table: :variation_annotation_has_consequence# , inverse_of: :consequences
  has_many :samples, through: :variation_annotations, inverse_of: :variation_annotations
  has_many :experiments, through: :samples, inverse_of: :variation_annotations

  # belongs_to :variation_annotation, inverse_of: :consequences
  has_many :variations, through: :variation_annotations, inverse_of: :variation_annotations
  
  
end
