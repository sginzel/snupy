class CreateVariations < ActiveRecord::Migration
  def change
    create_table :variations do |t|
      t.references :region
      t.references :alteration

      t.timestamps
    end
    add_index :variations, :region_id
    add_index :variations, :alteration_id
    add_index :variations, [:region_id, :alteration_id], :unique => true
  end
end
