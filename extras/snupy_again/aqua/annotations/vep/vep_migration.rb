class VepMigration < ActiveRecord::Migration
	@@CONFIG = YAML.load_file(File.join(Rails.root, "extras", "snupy_again", "aqua", "annotations" ,"vep", "vep_config.yaml"))[Rails.env]
	@@TABLENAME = "veps_v#{@@CONFIG["ensembl_version"]}s".to_sym # there is a pending s to be confirm with RAILS pluralized table form
	
	def up
		create_table @@TABLENAME do |t|
			t.references :variation, null: false
			t.references :organism, null: false
			
			t.string :impact
			t.string :consequence, null: false
			t.string :source #source field, Ensembl or RefSeq
			t.string :biotype
			t.string :most_severe_consequence
			t.string :dbsnp, limit: 1024
			t.string :dbsnp_allele, limit: 1024
			t.string :minor_allele
			t.float :minor_allele_freq
			t.string :exac_adj_allele
			t.float :exac_adj_maf
			t.string :gene_id
			t.string :transcript_id
			t.string :gene_symbol
			t.string :ccds
			t.integer :cdna_start
			t.integer :cdna_end
			t.integer :cds_start
			t.integer :cds_end
			t.boolean :canonical
			t.string :protein_id
			t.integer :protein_start
			t.integer :protein_end
			t.string :amino_acids
			t.string :codons
			# t.string :numbers #intron or exon
			t.float :numbers1
			t.float :numbers2
			t.string :hgvsc
			t.string :hgvsp
			t.integer :hgvs_offset
			t.integer :distance
			t.string :trembl_id
			t.string :uniparc
			t.string :swissprot
			t.string :polyphen_prediction, limit: 32
			t.float :polyphen_score
			t.string :sift_prediction, limit: 32
			t.float :sift_score
			t.string :domains, limit: 2048
			t.string :pubmed, limit: 2048
			t.boolean :somatic
			t.boolean :gene_pheno
			t.boolean :phenotype_or_disease
			t.boolean :allele_is_minor
			t.string :clin_sig, limit: 2048
			
			# motifs
			t.string :motif_feature_id
			t.string :motif_name
			t.boolean :high_inf_pos
			t.integer :motif_pos
			t.float :motif_score_change
			
			t.integer :bp_overlap, default: 1
			t.float :percentage_overlap, default: 100
			
			t.timestamps

		end
		
		add_index @@TABLENAME, [:variation_id, :organism_id, :source]
		
		add_index @@TABLENAME, :variation_id
		add_index @@TABLENAME, :organism_id
		
		add_index @@TABLENAME, :impact
		add_index @@TABLENAME, :consequence, null: false
		add_index @@TABLENAME, :source #source field, Ensembl or RefSeq
		add_index @@TABLENAME, :biotype
		add_index @@TABLENAME, :most_severe_consequence
		add_index @@TABLENAME, :dbsnp
		add_index @@TABLENAME, :dbsnp_allele
		add_index @@TABLENAME, :minor_allele
		add_index @@TABLENAME, :minor_allele_freq
		add_index @@TABLENAME, :exac_adj_allele
		add_index @@TABLENAME, :exac_adj_maf
		add_index @@TABLENAME, :gene_id
		add_index @@TABLENAME, :transcript_id
		add_index @@TABLENAME, :gene_symbol
		add_index @@TABLENAME, :ccds
		add_index @@TABLENAME, :cdna_start
		add_index @@TABLENAME, :cdna_end
		add_index @@TABLENAME, :cds_start
		add_index @@TABLENAME, :cds_end
		add_index @@TABLENAME, :canonical
		add_index @@TABLENAME, :protein_id
		add_index @@TABLENAME, :protein_start
		add_index @@TABLENAME, :protein_end
		add_index @@TABLENAME, :amino_acids
		add_index @@TABLENAME, :codons
		# add_index @@TABLENAME, :numbers #intron or exon
		add_index @@TABLENAME, :numbers1 #intron or exon
		add_index @@TABLENAME, :numbers2 #intron or exon
		add_index @@TABLENAME, :hgvsc
		add_index @@TABLENAME, :hgvsp
		add_index @@TABLENAME, :hgvs_offset
		add_index @@TABLENAME, :distance
		add_index @@TABLENAME, :trembl_id
		add_index @@TABLENAME, :uniparc
		add_index @@TABLENAME, :swissprot
		add_index @@TABLENAME, :polyphen_prediction
		add_index @@TABLENAME, :polyphen_score
		add_index @@TABLENAME, :sift_prediction
		add_index @@TABLENAME, :sift_score
		add_index @@TABLENAME, :domains
		add_index @@TABLENAME, :pubmed
		add_index @@TABLENAME, :somatic
		add_index @@TABLENAME, :gene_pheno
		add_index @@TABLENAME, :phenotype_or_disease
		
		add_index @@TABLENAME, :allele_is_minor
		
		add_index @@TABLENAME, :motif_feature_id
		add_index @@TABLENAME, :motif_name
		add_index @@TABLENAME, :high_inf_pos
		add_index @@TABLENAME, :motif_pos
		add_index @@TABLENAME, :motif_score_change
		
		add_index @@TABLENAME, :bp_overlap
		add_index @@TABLENAME, :percentage_overlap
		
	end

	def down
		drop_table @@TABLENAME
	end
	
end