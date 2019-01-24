class CaddMigration < ActiveRecord::Migration
	@@CONFIG = YAML.load_file(File.join(Rails.root, "extras", "snupy_again", "aqua", "annotations" ,"cadd", "cadd.yaml"))[Rails.env]
	@@TABLENAME = "cadd#{@@CONFIG["version"].to_s.gsub(".", "_")}s".to_sym # there is a pending s to be confirm with RAILS pluralized table form
	# create the table here
	def up
		create_table @@TABLENAME do |t|
			t.references :variation, null: false, unique: true
			t.float :raw
			t.float :phred
			t.references :organism, null: false
			# t.timestamps
		end
	
		add_index @@TABLENAME, :raw
		add_index @@TABLENAME, :phred
		add_index @@TABLENAME, :variation_id
		add_index @@TABLENAME, :organism_id
		
	end
	
	# destroy tables here
	def down
		drop_table @@TABLENAME
	end

end