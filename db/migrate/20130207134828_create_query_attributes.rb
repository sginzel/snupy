class CreateQueryAttributes < ActiveRecord::Migration
  def change
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
