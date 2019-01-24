class CreateStatistics < ActiveRecord::Migration
  def change
    create_table :statistics do |t|
			t.integer :record_id, null: false
      t.string :type, null: false
      t.string :name
      t.binary :value
      t.string :resource, null: false
      t.string :plotstyle, default: "table"
      

      t.timestamps
    end
    add_index :statistics, :record_id
    add_index :statistics, :type
    add_index :statistics, :resource
    add_index :statistics, [:record_id, :resource], uniq: true
  end
end
