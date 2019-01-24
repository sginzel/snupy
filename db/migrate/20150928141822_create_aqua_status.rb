class CreateAquaStatus < ActiveRecord::Migration
	def change
		create_table :aqua_statuses do |t|
			t.string :type # "AquaStatusAnnotation", "AquaStatusQuery", "AquaStatusFilter", "AquaStatusAggregation"
			t.string :category # arbitrary type of status - vcf_file, setup etc. 
			t.string :value # arbitrary value
			t.string :source # label of the tool or object
			t.integer :xref_id # object id in the database that the status links to.
			t.timestamps
		end
		
		add_index :aqua_statuses, :type
		add_index :aqua_statuses, :category
		add_index :aqua_statuses, :value
		add_index :aqua_statuses, :source
		add_index :aqua_statuses, :xref_id
		
	end
end
