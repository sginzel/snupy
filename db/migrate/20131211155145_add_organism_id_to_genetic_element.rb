class AddOrganismIdToGeneticElement < ActiveRecord::Migration
  def up
  	add_column :genetic_elements, :organism_id, :integer
  	add_index  :genetic_elements, :organism_id
  	execute "UPDATE #{GeneticElement.table_name} SET organism_id = 1"
  end
  
  def down
  	remove_index  :genetic_elements, :organism_id
  	remove_column :genetic_elements, :organism_id
  end
end
