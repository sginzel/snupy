class CreateQueryFilters < ActiveRecord::Migration
  def change
    create_table :query_filters do |t|
      t.string :type, null: false
      t.string :method, null: false
      t.string :label, null: false
      t.string :data_type, null: false
      t.string :input_type, null: false
      t.string :default_condition, null: false
      t.string :default_value, default: ""
      t.integer :priority, null: false, default: 100
      t.string :tooltip

      t.timestamps
    end
  end
end
