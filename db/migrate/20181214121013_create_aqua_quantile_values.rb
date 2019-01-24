class CreateAquaQuantileValues < ActiveRecord::Migration
  def change
    create_table :aqua_quantile_values do |t|
      t.references :aqua_quantile, null: false # aqua quantile
      t.float :quantile, null: false # quantile value [0,1]
      t.float :value # value at quantile

      t.timestamps
    end
    add_index :aqua_quantile_values, :aqua_quantile_id
    add_index :aqua_quantile_values, :quantile
    add_index :aqua_quantile_values, :value
    add_index :aqua_quantile_values, [:aqua_quantile_id, :quantile], unique: true

  end
end
