class CreateRegions < ActiveRecord::Migration
  def change
    create_table :regions do |t|
      t.string :name, null: false
      t.integer :start, null: false
      t.integer :stop, null: false
      t.string :coord_system, null: false

      t.timestamps
    end
  end
end
