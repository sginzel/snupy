class AddUniqueToVariationCall < ActiveRecord::Migration
  def up
  	## find and destroy possibly duplicated entries
  	d "identifiying duplicate entries in variation_calls..."
  	result = ActiveRecord::Base.connection.execute("
  							SELECT id, variation_id, sample_id 
  							FROM variation_calls
  						").to_a
  	lookup = {}
  	ids_to_delete = []
  	result.each do |id, varid, smplid|
  		if lookup[[varid, smplid]].nil? then
  			lookup[[varid, smplid]] = id
  		else
  			ids_to_delete << id
  		end
  	end
  	if ids_to_delete.size > 0 then
  		d "I found #{ids_to_delete.size} duplicate entries to remove in variation_calls...(this may take a while)"
  		VariationCall.destroy_all(id: ids_to_delete)
  	end
  	add_index :variation_calls, [:sample_id, :variation_id], :unique => true
  end
  
  def down
  	remove_index :variation_calls, [:sample_id, :variation_id]
  end
end
