class CaptureKitMigration < ActiveRecord::Migration
	@@CONFIG = YAML.load_file(File.join(Rails.root, "extras", "snupy_again", "aqua", "annotations" ,"capture_kit", "capture_kit.yaml"))[Rails.env]
	@@TABLENAME = "capture_kit#{@@CONFIG["version"].to_s.gsub(".", "_")}s".to_sym # there is a pending s to be confirm with RAILS pluralized table form
	@@CKFILETABLENAME = "capture_kit_file#{@@CONFIG["version"].to_s.gsub(".", "_")}s".to_sym # there is a pending s to be confirm with RAILS pluralized table form
	# create the table here
	def up
		create_table @@TABLENAME do |t|
			t.references :variation, null: false, unique: true
			t.references :organism, null: false
			t.integer    :dist, :limit => 2   # smallint (2 bytes, max 32,767)
			t.references :capture_kit_file, null: false
			# t.timestamps
		end

		create_table @@CKFILETABLENAME do |t|
			t.string :name, null: false, unique: true # descriptive name
			t.string :description # description (optional)
			t.string :file, null: false # filename
			t.string :localfile, null: false # a copy of the content on the local disc
			t.string :chromosomes, null: false # comma seperated list of chromosomes present
			t.integer :bp, null: false # number of bases
			t.string :capture_type, null: false # the type of capture file. Can be exome_capture, genetic_region, regulatory_region, other
			t.binary :content, null: false, limit: 50.megabyte # 50MB max size - gzipped. BED formated.
			t.references :organism, null: false
			# t.timestamps
		end

		add_index @@TABLENAME, :variation_id
		add_index @@TABLENAME, :organism_id
		add_index @@TABLENAME, :dist
		add_index @@TABLENAME, :capture_kit_file_id
		add_index @@TABLENAME, [:variation_id, :capture_kit_file_id], unique: true


		add_index @@CKFILETABLENAME, :name
		add_index @@CKFILETABLENAME, :file
		add_index @@CKFILETABLENAME, :localfile
		add_index @@CKFILETABLENAME, :bp
		add_index @@CKFILETABLENAME, :capture_type
		add_index @@CKFILETABLENAME, :organism_id

	end

	# destroy tables here
	def down
		drop_table @@TABLENAME
		drop_table @@CKFILETABLENAME
	end

end