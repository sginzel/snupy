class StringdbMigration < ActiveRecord::Migration
	def up
		
		create_table :string_proteins do |t|
			t.string :stringdb_id, null: false
			t.string :ensembl_protein_id, null: false
			t.integer :taxon_id
			t.references :organism, null: false
		end
		
		create_table :string_protein_links do |t|
			t.string :stringdb1_id, null: false
			t.string :stringdb2_id, null: false
			t.integer :neighborhood
			t.integer :neighborhood_transferred
			t.integer :fusion
			t.integer :cooccurence
			t.integer :homology
			t.integer :coexpression
			t.integer :coexpression_transferred
			t.integer :experiments
			t.integer :experiments_transferred
			t.integer :database
			t.integer :database_transferred
			t.integer :textmining
			t.integer :textmining_transferred
			t.integer :combined_score

			t.integer :taxon_id
			t.references :organism, null: false
			
			t.timestamps
		end
		
		create_table :string_protein_actions do |t|
			t.string :stringdb1_id, null: false
			t.string :stringdb2_id, null: false
			t.string  :mode
			t.string  :action
			# t.string  :sources
			# t.string  :transfered_sources
			t.string  :a_is_acting
			t.string  :score
			
			t.integer :bind, limit: 2
			t.integer :biocarta, limit: 2
			t.integer :biocyc, limit: 2
			t.integer :dip, limit: 2
			t.integer :grid, limit: 2
			t.integer :hprd, limit: 2
			t.integer :intact, limit: 2
			t.integer :kegg_pathways, limit: 2
			t.integer :mint, limit: 2
			t.integer :pdb, limit: 2
			t.integer :pid, limit: 2
			t.integer :reactome, limit: 2
			
			t.integer :taxon_id
			t.references :organism, null: false
		end
		
		create_table :string_protein_alias do |t|
			t.string :stringdb_id, null: false
			t.string :ensembl_protein_id, null: false
			t.string :alias, null: false
			t.string :source
			t.integer :taxon_id
			t.references :organism, null: false
		end
		
		add_index :string_protein_links, :stringdb1_id
		add_index :string_protein_links, :stringdb2_id
		add_index :string_protein_links, :neighborhood
		add_index :string_protein_links, :neighborhood_transferred
		add_index :string_protein_links, :fusion
		add_index :string_protein_links, :cooccurence
		add_index :string_protein_links, :homology
		add_index :string_protein_links, :coexpression
		add_index :string_protein_links, :coexpression_transferred
		add_index :string_protein_links, :experiments
		add_index :string_protein_links, :experiments_transferred
		add_index :string_protein_links, :database
		add_index :string_protein_links, :database_transferred
		add_index :string_protein_links, :textmining
		add_index :string_protein_links, :textmining_transferred
		add_index :string_protein_links, :combined_score
		
		add_index :string_protein_actions, :stringdb1_id
		add_index :string_protein_actions, :stringdb2_id
		add_index :string_protein_actions, :mode
		add_index :string_protein_actions, :action
		# add_index :string_protein_links, :sources
		# add_index :string_protein_links, :transfered_sources
		add_index :string_protein_actions, :a_is_acting
		add_index :string_protein_actions, :score
		add_index :string_protein_actions, :organism_id
		add_index :string_protein_actions, :taxon_id
		
		add_index :string_protein_actions, :bind
		add_index :string_protein_actions, :biocarta
		add_index :string_protein_actions, :biocyc
		add_index :string_protein_actions, :dip
		add_index :string_protein_actions, :grid
		add_index :string_protein_actions, :hprd
		add_index :string_protein_actions, :intact
		add_index :string_protein_actions, :kegg_pathways
		add_index :string_protein_actions, :mint
		add_index :string_protein_actions, :pdb
		add_index :string_protein_actions, :pid
		add_index :string_protein_actions, :reactome
		
		add_index :string_protein_alias, :stringdb_id
		add_index :string_protein_alias, :ensembl_protein_id
		add_index :string_protein_alias, :alias
		add_index :string_protein_alias, :source
		add_index :string_protein_alias, :organism_id
		add_index :string_protein_alias, :taxon_id
		
		add_index :string_proteins, :stringdb_id, unique: true
		add_index :string_proteins, :ensembl_protein_id, unique: true
		add_index :string_proteins, :organism_id
		add_index :string_proteins, :taxon_id
		
	end

	def down
		drop_table :string_protein_links
		drop_table :string_protein_actions
		drop_table :string_protein_alias
		drop_table :string_proteins
	end
end