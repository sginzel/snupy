class AddUniqueToRegionAndAlteration < ActiveRecord::Migration
  def change
  	remove_index :alterations, name: :unique_field_combo_alteration
  	add_index :alterations, [:ref, :alt], 
  													unique: true, 
  													name: "unique_ref_alt_pairs",
  													length: {ref: 128, alt: 128} # this could become a problem when there are two very long exchanges that are really the same up to the 383 position....
  	add_index :regions, [:name, :start, :stop, :coord_system], unique: true, name: "unique_pairs"
  end
end
