class CreateEntities < ActiveRecord::Migration
	def change
		create_table :entities do |t|
			t.string :name
			t.string :nickname
			t.string :internal_identifier
			t.string :contact
			t.datetime :date_first_diagnosis
			t.boolean :family_members_available
			t.text :notes
			#t.references :institution
			t.references :entity_group
			t.timestamps
		end
		
		add_index :entities, :name
		add_index :entities, :nickname
		add_index :entities, :internal_identifier
		add_index :entities, :date_first_diagnosis
		add_index :entities, :family_members_available
		
		#add_index :entities, :institution_id
		add_index :entities, :entity_group_id
		
		
	end
end
