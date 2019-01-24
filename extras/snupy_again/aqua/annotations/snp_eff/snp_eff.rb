class SnpEff < ActiveRecord::Base

	belongs_to :variation
	belongs_to :organism
	has_one :alteration, through: :variation
	has_one :region, through: :variation
	has_many :variation_calls, foreign_key: :variation_id, primary_key: :variation_id
	has_many :samples, through: :variation_calls
	has_many :users, through: :samples
	has_many :experiments, through: :samples


	attr_accessible :variation_id, :organism_id, :annotation, :annotation_impact, :symbol, :ensembl_gene_id, :ensembl_feature_type, :ensembl_feature_id, :transcript_biotype, :hgvs_c, :hgvs_p, :cdna_pos, :cdna_length, :cds_pos, :cds_length, :aa_pos,  :aa_length, :distance,
	:lof_gene_name, :lof_gene_id, :lof_number_of_transcripts_in_gene, :lof_percent_of_transcripts_affected,
	:nmd_gene_name, :nmd_gene_id, :nmd_number_of_transcripts_in_gene, :nmd_percent_of_transcripts_affected

	# scope :full, joins(:variation, :organism)

end
