class RemoveQueryAttributeModel < ActiveRecord::Migration
  def up
  	if table_exists?(:query_attributes) then
  		drop_table :query_attributes
  	end
  end

  def down
  	create_table :query_attributes do |t|
      t.string :type, null: false
      t.string :method, null: false
      t.string :label, null: false
			t.string :data_type, null: false
      t.integer :priority, null: false, default: 100
			t.boolean :checked, default: false
      t.string :tooltip

      t.timestamps
    end
  end
end
