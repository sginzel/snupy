class AddIndexToVcfFileAndExperiment < ActiveRecord::Migration
	def change
		add_index :vcf_files, :name
		add_index :vcf_files, :type
		add_index :vcf_files, :organism_id
		add_index :experiments, :name
		add_index :experiments, :title
	end
end
