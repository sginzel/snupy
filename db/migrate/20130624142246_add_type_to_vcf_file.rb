class AddTypeToVcfFile < ActiveRecord::Migration
  def change
  	add_column :vcf_files, :type, :string, default: "VcfFile"
  end
end
