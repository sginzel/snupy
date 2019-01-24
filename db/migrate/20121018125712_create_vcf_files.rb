class CreateVcfFiles < ActiveRecord::Migration
  def change
    create_table :vcf_files do |t|
    	t.string :name, null: false, unique: true
      t.string :filename, null: false
      t.binary :content, null: false, limit: 100.megabyte
      t.string :md5checksum
      t.string :sample_names, null: false
      t.string :contact, null: false
      t.string :status, default: :CREATED
			t.references :institution
			t.references :organism, null: false
      t.timestamps
    end
    add_index :vcf_files, :institution_id
  end
end
