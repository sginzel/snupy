
class AnnovarMigration < ActiveRecord::Migration

	def up
		create_table :annovars do |t|
			t.references :variation, null: false
			t.references :organism, null: false
			t.string :ensembl_annovar_annotation
			t.string :ensembl_annotation
			t.string :ensembl_gene
			t.string :ensembl_effect_transcript
			t.string :ensembl_region_sequence_change
			t.string :ensembl_dna_sequence_change
			t.string :ensembl_protein_sequence_change
			t.string :ensembl_right_gene_neighbor
			t.integer :ensembl_distance_to_right_gene_neighbor
			t.string :ensembl_left_gene_neighbor
			t.integer :ensembl_distance_to_left_gene_neighbor
			t.string :refgene_annovar_annotation
			t.string :refgene_annotation
			t.string :refgene_gene
			t.string :refgene_effect_transcript
			t.string :refgene_region_sequence_change
			t.string :refgene_dna_sequence_change
			t.string :refgene_protein_sequence_change
			t.string :refgene_left_gene_neighbor
			t.integer :refgene_distance_to_left_gene_neighbor
			t.string :refgene_right_gene_neighbor
			t.integer :refgene_distance_to_right_gene_neighbor
			t.boolean :ensembl_gene_is_refgene_alias
			t.boolean :ensembl_transcript_is_refgene_transcript_alias
			t.string :wgrna_name
			t.string :micro_rna_target_name
			t.float :micro_rna_target_score
			t.string :tfbs_motif_name
			t.float :tfbs_score
			t.string :genomic_super_dups_name
			t.float :genomic_super_dups_score
			t.string :gwas_catalog, size: 2048
			t.string :variant_clinical_significance, size: 2048
			t.string :variant_disease_name, size: 2048
			t.string :variant_revstat, size: 2048
			t.string :variant_accession_versions, size: 2048
			t.string :variant_disease_database_name, size: 2048
			t.string :variant_disease_database_id, size: 2048
			t.float :sift_score
			t.string :sift_pred
			t.float :polyphen2_hdvi_score
			t.string :polyphen2_hdvi_pred
			t.float :polyphen2_hvar_score
			t.string :polyphen2_hvar_pred
			t.float :lrt_score
			t.string :lrt_pred
			t.float :mutation_taster_score
			t.string :mutation_taster_pred
			t.float :mutation_assessor_score
			t.string :mutation_assessor_pred
			t.float :fathmm_score
			t.string :fathmm_pred
			t.float :radial_svm_score
			t.string :radial_svm_pred
			t.float :lr_score
			t.string :lr_pred
			t.float :vest3_score
			t.float :cadd_raw
			t.float :cadd_phred
			t.float :gerp_rs
			t.float :phylop46way_placental
			t.float :phylop100way_vertebrate
			t.float :siphy_29way_logOdds
			t.float :genome_2014oct
			t.string :snp138
			t.float :esp6500siv2_all
			t.float :gerp_gt2
			t.float :cg69
			t.string :cosmic68_id
			t.string :cosmic68_occurence, size: 2048
			t.float :exac_all
			t.timestamps

		end
		add_index :annovars, :variation_id
		add_index :annovars, :organism_id
		add_index :annovars, :ensembl_annovar_annotation
		add_index :annovars, :ensembl_annotation
		add_index :annovars, :ensembl_gene
		add_index :annovars, :ensembl_effect_transcript
		add_index :annovars, :refgene_annovar_annotation
		add_index :annovars, :refgene_annotation
		add_index :annovars, :refgene_gene
		add_index :annovars, :refgene_effect_transcript
		add_index :annovars, :ensembl_gene_is_refgene_alias
		add_index :annovars, :ensembl_transcript_is_refgene_transcript_alias
		add_index :annovars, :micro_rna_target_name
		add_index :annovars, :micro_rna_target_score
		add_index :annovars, :tfbs_motif_name
		add_index :annovars, :tfbs_score
		add_index :annovars, :gwas_catalog
		add_index :annovars, :variant_clinical_significance
		add_index :annovars, :variant_disease_name
		add_index :annovars, :sift_score
		add_index :annovars, :sift_pred
		add_index :annovars, :polyphen2_hdvi_score
		add_index :annovars, :polyphen2_hdvi_pred
		add_index :annovars, :polyphen2_hvar_score
		add_index :annovars, :polyphen2_hvar_pred
		add_index :annovars, :lrt_score
		add_index :annovars, :lrt_pred
		add_index :annovars, :mutation_taster_score
		add_index :annovars, :mutation_taster_pred
		add_index :annovars, :mutation_assessor_score
		add_index :annovars, :mutation_assessor_pred
		add_index :annovars, :fathmm_score
		add_index :annovars, :fathmm_pred
		add_index :annovars, :radial_svm_score
		add_index :annovars, :radial_svm_pred
		add_index :annovars, :lr_score
		add_index :annovars, :lr_pred
		add_index :annovars, :vest3_score
		add_index :annovars, :cadd_raw
		add_index :annovars, :cadd_phred
		add_index :annovars, :gerp_rs
		add_index :annovars, :phylop46way_placental
		add_index :annovars, :phylop100way_vertebrate
		add_index :annovars, :siphy_29way_logOdds
		add_index :annovars, :genome_2014oct
		add_index :annovars, :snp138
		add_index :annovars, :esp6500siv2_all
		add_index :annovars, :gerp_gt2
		add_index :annovars, :cg69
		add_index :annovars, :cosmic68_id
		add_index :annovars, :cosmic68_occurence
		add_index :annovars, :exac_all
		
		create_table :annovar_ensembl2alias do |t|
			t.string :ensembl_id, null: false
			t.string :alias, null: false
			t.string :dbname, null: false
			t.references :organism, null: false
		end
		add_index :annovar_ensembl2alias, :ensembl_id
		add_index :annovar_ensembl2alias, :alias
		add_index :annovar_ensembl2alias, :dbname
		add_index :annovar_ensembl2alias, :organism_id
		
		insert_ensembl_ids()
	end

	def down
		drop_table :annovars
		drop_table :annovar_ensembl2alias
	end
	
	def insert_ensembl_ids()
		databases = {
			"homo_sapiens_core_75_37" => {symbol: ["'HGNC'"], ucsc: ["'RefSeq_mRNA'", "'RefSeq_mRNA_predicted'"], organism_id: Organism.find_by_name("homo sapiens").id},
			"mus_musculus_core_75_38" => {symbol: ["'MGI'"], ucsc: ["'RefSeq_mRNA'", "'RefSeq_mRNA_predicted'"],  organism_id: Organism.find_by_name("mus musculus").id},
		}
		
		d "connecting to public ensembl database..."
		# for Ensembl Version 80_37 use this
		# client = Mysql2::Client.new(:host => "ensembldb.ensembl.org", :username => "anonymous", port: 3337)
		# else use this
		client = Mysql2::Client.new(:host => "ensembldb.ensembl.org", :username => "anonymous", port: 3306)
		d "OK."
		
		begin
			databases.each do |dbname, symAndTrans|
				d "processing #{dbname}"
				statement_symbol = "
					SELECT stable_id AS ensembl_id, display_label AS alias, db_name
					FROM #{dbname}.object_xref
					INNER JOIN #{dbname}.gene ON (#{dbname}.gene.gene_id = #{dbname}.object_xref.ensembl_id AND ensembl_object_type = 'Gene')
					INNER JOIN #{dbname}.xref ON (#{dbname}.xref.xref_id = #{dbname}.object_xref.xref_id)
					INNER JOIN #{dbname}.external_db USING (external_db_id)
					WHERE external_db.db_name IN (#{symAndTrans[:symbol].join(",")})"
				statement_transcripts = "
					SELECT stable_id AS ensembl_id, display_label AS alias, db_name
					FROM #{dbname}.object_xref
					INNER JOIN #{dbname}.transcript ON (#{dbname}.transcript.transcript_id = #{dbname}.object_xref.ensembl_id AND ensembl_object_type = 'Transcript')
					INNER JOIN #{dbname}.xref ON (#{dbname}.xref.xref_id = #{dbname}.object_xref.xref_id)
					INNER JOIN #{dbname}.external_db USING (external_db_id)
					WHERE external_db.db_name IN (#{symAndTrans[:ucsc].join(",")})"
				[statement_symbol, statement_transcripts].each do |statement|
					buffer = []
					client.query(statement).each do |row|
						buffer << [row["ensembl_id"], row["alias"], row["db_name"], symAndTrans[:organism_id]]
						if buffer.size > 1000
							SnupyAgain::DatabaseUtils.sql_mass_insert("annovar_ensembl2alias", ["ensembl_id", "alias", "dbname", "organism_id"], buffer)
							buffer = []
						end
					end
					SnupyAgain::DatabaseUtils.sql_mass_insert("annovar_ensembl2alias", ["ensembl_id", "alias", "dbname", "organism_id"], buffer) if buffer.size > 0
				end
			end
			d "DONE."
		rescue 
			d "Error occured during ensembl database import"
			raise
		ensure
			d "closing SQL connection..."
			client.close
		end
	end

end