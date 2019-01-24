class AddUniqueIndexToVcfChecksum < ActiveRecord::Migration
	def up
		remove_index :vcf_files, :md5checksum
		remove_index :vcf_files, :institution_id
		
		add_index :vcf_files, :md5checksum, unique: true
		add_index :vcf_files, :institution_id, null: false
		add_index :vcf_files, :filename
		add_index :vcf_files, :contact
	end
	
	def down
		remove_index :vcf_files, :filename
		remove_index :vcf_files, :contact
	end
end
