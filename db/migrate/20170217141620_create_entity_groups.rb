class CreateEntityGroups < ActiveRecord::Migration
	def change
		create_table :entity_groups do |t|
			t.string :name
			t.boolean :complete
			t.string :contact
			t.references :institution
			t.references :organism
			t.timestamps
		end
		
		create_table :experiment_has_entity_groups do |t|
			t.references :experiment
			t.references :entity_group
		end
		
# TODO delete me
#		create_table :institution_has_entity_groups do |t|
#			t.references :institution
#			t.references :entity_group
#		end
		
		create_table :user_has_entity_groups do |t|
			t.references :user
			t.references :entity_group
		end
		
		add_index :entity_groups, :name
		add_index :entity_groups, :institution_id
		add_index :entity_groups, :organism_id
		add_index :entity_groups, :complete
		add_index :experiment_has_entity_groups, :experiment_id
		add_index :experiment_has_entity_groups, :entity_group_id
		add_index :experiment_has_entity_groups, [:experiment_id, :entity_group_id], name: "exp_eg_index", unique: true
		
#		add_index :institution_has_entity_groups, :institution_id
#		add_index :institution_has_entity_groups, :entity_group_id
#		add_index :institution_has_entity_groups, [:institution_id, :entity_group_id], name: "inst_eg_index", unique: true
		
		add_index :user_has_entity_groups, :user_id
		add_index :user_has_entity_groups, :entity_group_id
		add_index :user_has_entity_groups, [:user_id, :entity_group_id], name: "user_eg_index", unique: true
	end
end
