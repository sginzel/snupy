class ChangeSampleVcfFileId < ActiveRecord::Migration
  def up
  	change_column(:samples, :vcf_file_id, :integer, null: true)
  	change_column(:samples, :vcf_sample_name, :string, null: true)
  end
  
  def down
  	change_column(:samples, :vcf_file_id, :integer, null: false)
  	change_column(:samples, :vcf_sample_name, :string, null: false)
  end
end
