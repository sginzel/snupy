class CreateVcfFileIndices < ActiveRecord::Migration
	def change
		create_table :vcf_file_indices do |t|
			t.references :vcf_file, null: false
			t.binary :index, limit: 250.megabyte
			t.binary :varlist, limit: 16.megabyte
			t.boolean :compressed, default: true
			t.string :format, default: "bin"
			t.timestamps
		end
		add_index :vcf_file_indices, :vcf_file_id, unique: true
	end
end
