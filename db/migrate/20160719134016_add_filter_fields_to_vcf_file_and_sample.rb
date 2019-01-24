class AddFilterFieldsToVcfFileAndSample < ActiveRecord::Migration
	# add filters field to vcf file
	# invoke get_filter_values_from_content for each vcf file
	# add filters field to samples
	# if the ignore_filter option is set then 
	#    add all filters from vcf file to the sample
	# else 
	#    only add PASS
	def up
		add_column :vcf_files, :filters, :string, limit: 16384, default: {PASS: -1}.to_yaml
		add_column :samples, :filters, :string, limit: 16384, default: "PASS"
		
	end
	
	# remove filters field from samples
	# remove filters field from vcf file
	def down
		remove_column :vcf_files, :filters
		remove_column :samples, :filters
	end
end
