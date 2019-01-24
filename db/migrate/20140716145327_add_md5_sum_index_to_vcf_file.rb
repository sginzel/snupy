class AddMd5SumIndexToVcfFile < ActiveRecord::Migration
  def change
		add_index :vcf_files, :md5checksum
  end
end
