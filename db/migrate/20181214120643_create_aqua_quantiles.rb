class CreateAquaQuantiles < ActiveRecord::Migration
  def change
    create_table :aqua_quantiles do |t|
      t.string :model, null: false # YAML dump of the model
      t.integer :direction, default: 1 # 1 or -1 depending on whether values for the quantiles should be ranked in ascending or descending order
      t.binary :estimator, limit: 10.megabytes # Marshalled Quantile::Esitmator object -> Marhsaled is much smaller than YAML.dump
      t.string :model_table, null: false # the table name needs to be preserved in case the model changes its table name
      t.string :attribute_column, null: false # the attributes column name to retrieve the observations
      t.integer :organism_id, null: false # quantiles depend on the organism
      t.integer :last_variation_id, default: 0 # stores the last variation id, the quantiles were computed to

      t.timestamps
    end
    add_index :aqua_quantiles, :model
    add_index :aqua_quantiles, :attribute_column
    add_index :aqua_quantiles, :direction
    add_index :aqua_quantiles, :model_table
    add_index :aqua_quantiles, :organism_id
    add_index :aqua_quantiles, :last_variation_id
    
    add_index :aqua_quantiles, [:model_table, :organism_id, :attribute_column], unique: true, name: "unique_table_attribute_name_organism"
    
  end
end
