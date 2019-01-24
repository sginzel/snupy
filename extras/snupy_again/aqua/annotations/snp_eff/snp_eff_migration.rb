
class SnpEffMigration < ActiveRecord::Migration

	def up
		create_table :snp_effs do |t|
			t.references :variation, null: false
			t.references :organism, null: false
			# t.string :allele
			t.string :annotation
			t.string :annotation_impact
			t.string :symbol
			t.string :ensembl_gene_id
			t.string :ensembl_feature_type
			t.string :ensembl_feature_id
			t.string :transcript_biotype
			t.string :hgvs_c
			t.string :hgvs_p
			t.integer :cdna_pos
			t.integer :cdna_length
			t.integer :cds_pos
			t.integer :cds_length
			t.integer :aa_pos
			t.integer :aa_length
			t.integer :distance
			#t.string :wanings
			#t.string :info
			t.integer :genotype_number
			t.string :lof_gene_name
			t.string :lof_gene_id
			t.integer :lof_number_of_transcripts_in_gene
			t.float :lof_percent_of_transcripts_affected
			t.string :nmd_gene_name
			t.string :nmd_gene_id
			t.integer :nmd_number_of_transcripts_in_gene
			t.float :nmd_percent_of_transcripts_affected

			t.timestamps
		end
		add_index :snp_effs, :variation_id
		add_index :snp_effs, :organism_id
		add_index :snp_effs, :annotation
		add_index :snp_effs, :annotation_impact
		add_index :snp_effs, :symbol
		add_index :snp_effs, :ensembl_gene_id
		add_index :snp_effs, :ensembl_feature_type
		add_index :snp_effs, :ensembl_feature_id
		add_index :snp_effs, :transcript_biotype
		add_index :snp_effs, :lof_number_of_transcripts_in_gene
		add_index :snp_effs, :lof_percent_of_transcripts_affected
		add_index :snp_effs, :nmd_gene_name
	end

	def down
		drop_table :snp_effs
	end
end