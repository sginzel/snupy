class AddOrganismIndexToVariationAnnotations < ActiveRecord::Migration
  def change
  	add_index :variation_annotations, :organism_id
  end
end
