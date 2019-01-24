class CreateVariationCalls < ActiveRecord::Migration
  def change
    create_table :variation_calls do |t|
      t.references :sample
      t.references :variation
      t.float :qual
      t.string :filter
      t.string :gt
      t.string :ps
      t.integer :dp
      t.float :gl
      t.float :gq

      t.timestamps
    end
    add_index :variation_calls, :sample_id
    add_index :variation_calls, :variation_id
  end
end
