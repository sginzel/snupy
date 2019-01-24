class AddEntityAndEntityGroupToSample < ActiveRecord::Migration
	def up
		add_column :samples, :entity_id, :integer, default: nil
		add_column :samples, :entity_group_id, :integer, default: nil
		
		add_index :samples, :entity_id
		add_index :samples, :entity_group_id
		
		# calling Sample.reset_column_information is neccessary to reload and process new columns
		Sample.reset_column_information
		# add associations for all samples
		Sample.where("specimen_probe_id IS NOT NULL").includes([:entity, :entity_group]).each do |smpl|
			print "processing: #{smpl.name}                                               \r"
			smpl.save
		end
		print "DONE\n"
		
	end
	
	def down
		remove_column :samples, :entity_id
		remove_column :samples, :entity_group_id
	end
end