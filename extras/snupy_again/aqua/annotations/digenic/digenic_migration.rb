class DigenicMigration < ActiveRecord::Migration
	def up
		
		create_table :digenics do |t|
			t.string :gene_id, null: false # any gene id
			t.string :gene_partner_id, null: false # the partner gene id
			t.float :score, null: false, default: 1.0 # an arbitrary score (0-1) that indicates the importance of the association
			t.string :disease_name, default: nil # an associated disease name
			t.string :association_description, default: nil # a short description how the genes interact in context of the disease
			t.string :evidence_record, size: 1024 # a full copy of the record parsed from the source database - for review by the user
			t.string :source_db, null: false # source database name
			t.string :source_id, default: nil # source association id, if provided
			t.string :source_file, null: false, size: 1024 # source file name
			t.references :organism, null: false # required for aqua annotation modules
			t.timestamps
		end
		
		add_index :digenics, :gene_id
		add_index :digenics, :gene_partner_id
		add_index :digenics, :score
		add_index :digenics, :disease_name
		add_index :digenics, :association_description
		add_index :digenics, :evidence_record
		add_index :digenics, :source_db
		add_index :digenics, :source_id
		add_index :digenics, :source_file
		add_index :digenics, :organism_id
	
	end
	
	def down
		drop_table :digenics
	end
end