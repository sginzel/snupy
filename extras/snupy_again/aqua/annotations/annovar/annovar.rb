class AnnovarAlias < ActiveRecord::Base
	self.table_name = "annovar_ensembl2alias"
	belongs_to :annovar, 
		primary_key: "ensembl_gene", 
		foreign_key: "ensembl_id",
		readonly: true
		
	attr_reader :id, :ensembl_gene_id, :alias, :dbname, :organism_id
end

class Annovar < ActiveRecord::Base
	extend SnupyAgain::AnnotationSummary
	belongs_to :variation
	belongs_to :organism
	has_one :alteration, through: :variation
	has_one :region, through: :variation
	has_many :variation_calls, foreign_key: :variation_id, primary_key: :variation_id
	has_many :samples, through: :variation_calls
	has_many :users, through: :samples
	has_many :experiments, through: :samples
	
	has_many :gene_names, 
		class_name: "AnnovarAlias",
		primary_key: "ensembl_gene", 
		foreign_key: "ensembl_id",
		# conditions: ['annovars.organism_id = annovar_ensembl2alias.organism_id'], 
		readonly: true
	
	attr_accessible :variation_id,
					:organism_id,
					:ensembl_annovar_annotation, :ensembl_annotation, :ensembl_gene, :ensembl_effect_transcript, :ensembl_region_sequence_change, :ensembl_dna_sequence_change,  :ensembl_protein_sequence_change,:ensembl_right_gene_neighbor, :ensembl_distance_to_right_gene_neighbor, :ensembl_left_gene_neighbor, :ensembl_distance_to_left_gene_neighbor,
					:refgene_annovar_annotation, :refgene_annotation, :refgene_gene, :refgene_effect_transcript, :refgene_region_sequence_change,:refgene_dna_sequence_change, :refgene_protein_sequence_change, :refgene_left_gene_neighbor, :refgene_distance_to_left_gene_neighbor, :refgene_right_gene_neighbor, :refgene_distance_to_right_gene_neighbor,
					:wgrna_name,
					:micro_rna_target_name, :micro_rna_target_score,
					:tfbs_motif_name, :tfbs_score,
					:genomic_super_dups_name, :genomic_super_dups_score,
					:gwas_catalog,
					:variant_clinical_significance, :variant_disease_name, :variant_revstat, :variant_accession_versions, :variant_disease_database_name, :variant_disease_database_id,
					:sift_score, :sift_pred, :polyphen2_hdvi_score, :polyphen2_hdvi_pred, :polyphen2_hvar_score, :polyphen2_hvar_pred, :lrt_score, :lrt_pred, :mutation_taster_score, :mutation_taster_pred, :mutation_assessor_score, :mutation_assessor_pred, :fathmm_score, :fathmm_pred, :radial_svm_score, :radial_svm_pred, :lr_score, :lr_pred, :vest3_score, :cadd_raw, :cadd_phred, :gerp_rs,
					:phylop46way_placental, :phylop100way_vertebrate,
					:siphy_29way_logOdds, :genome_2014oct,
					:snp138,
					:esp6500siv2_all,
					:gerp_gt2,
					:cg69,
					:cosmic68_id, :cosmic68_occurence,
					:exac_all,
					:ensembl_transcript_is_refgene_transcript_alias, :ensembl_gene_is_refgene_alias
	# scope :full, joins(:variation, :organism)
	
	# quantile based summary of the Conservation, LOFP and Frequencies
	def self.summary_categories()
		summary = {
			Conservation_q: [:gerp_rs, :phylop46way_placental, :phylop100way_vertebrate, :siphy_29way_logOdds],
			LOFP_q: [:cadd_phred, :vest3_score, :mutation_taster_score, :lrt_score,
			       :mutation_assessor_score, :polyphen2_hvar_score,
			       :polyphen2_hdvi_score, :sift_score, :fathmm_score, :radial_svm_score,
	               :lr_score],
			Frequency_q: [:exac_all, :genome_2014oct, :esp6500siv2_all]
		}
		summary
		
	end
	
	def summary_old()
		summary = {
				Conservation: 0, # gerp_rs: -12,0,2,6, phylop46way_placental: -10,0,1.5,3, phylop100way_vertebrate: -10,0,1.5,3, siphy_29way_logOdds: -10,0,2,4
				LOFP: 0,   # cadd: 0, 10, 20, vest3_score: 0, 0.5, 1, mutation_taster_pred: N < P < A < D, mutation_assessor_pred: N < L < M < H, polyphen2_hvar_pred/polyphen2_hdvi_pred: T < B < P < D, sift_pred: T < B < A < D
				Frequency: 0 # exac_all: 1 < 0.1 < 0.01 < 0.001 < 0 (0, 25, 75, 90, 100)
		}

		### Conservation
		if gerp_rs.to_i > 6 then
			summary[:Conservation] += 20
		elsif gerp_rs.to_i > 4 then
			summary[:Conservation] += 15
		elsif gerp_rs.to_i > 2 then
			summary[:Conservation] += 10
		end
		if phylop46way_placental.to_i > 3 then
			summary[:Conservation] += 20
		elsif phylop46way_placental.to_i > 1.5 then
			summary[:Conservation] += 15
		elsif phylop46way_placental.to_i > 1 then
			summary[:Conservation] += 10
		end
		if phylop100way_vertebrate.to_i > 3 then
			summary[:Conservation] += 20
		elsif phylop100way_vertebrate.to_i > 1.5 then
			summary[:Conservation] += 10
		end
		if siphy_29way_logOdds.to_i > 4 then
			summary[:Conservation] += 20
		elsif siphy_29way_logOdds.to_i > 2 then
			summary[:Conservation] += 15
		elsif siphy_29way_logOdds.to_i > 1 then
			summary[:Conservation] += 10
		end
		summary[:Conservation] = ((summary[:Conservation].to_f/80)*100).round(0) # scale it to 100

		# LOFP
		if cadd_phred.to_i > 20 then
			summary[:LOFP] += 14
		elsif cadd_phred.to_i > 10 then
			summary[:LOFP] += 7
		end
		if vest3_score.to_f > 0.9 then
			summary[:LOFP] += 14
		elsif vest3_score.to_f > 0.5 then
			summary[:LOFP] += 7
		end
		summary[:LOFP] += case mutation_assessor_pred
											when "H"
												14
											when "M"
												7
											when "L"
												3
											else
												0
											end
		summary[:LOFP] += case mutation_taster_pred
											when "D"
												14
											when "A"
												7
											when "P"
												3
											else
												0
											end
		# polyphen2_hvar_pred/polyphen2_hdvi_pred: T < B < P < D, sift_pred: T < B < A < D
		summary[:LOFP] += case polyphen2_hvar_pred
											when "D"
												14
											when "P"
												7
											when "B"
												3
											else
												0
											end
		summary[:LOFP] += case polyphen2_hdvi_pred
											when "D"
												14
											when "P"
												7
											when "B"
												3
											else
												0
											end
		summary[:LOFP] += case sift_pred
											when "D"
												14.28
											when "A"
												7
											when "B"
												3
											else
												0
											end
		summary[:LOFP] = ((summary[:LOFP].to_f/98)*100).round(0) # scale it to 100
		summary[:Frequency] = if exac_all.nil? then
														100
													elsif exac_all < 0.001 then
														100
													elsif exac_all < 0.01 then
														75
													elsif exac_all < 0.1 then
														25
													else
														0
													end

		summary
	end
end