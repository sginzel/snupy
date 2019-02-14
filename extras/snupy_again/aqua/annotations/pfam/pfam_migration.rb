class PfamMigration < ActiveRecord::Migration
	@@CONFIG          = YAML.load_file(File.join(Aqua.annotationdir ,"pfam", "pfam_config.yaml"))[Rails.env]
	@@TABLENAME       = "pfam#{@@CONFIG["version"].to_s.gsub(".", "_")}s".to_sym # there is a pending s to be confirm with RAILS pluralized table form
	
	# create the table here
	def up
		create_table @@TABLENAME  do |t|
			t.references :variation, null: false # required
			t.references :organism, null: false # required
			t.timestamps # optional
		end
		
		add_index @@TABLENAME, :variation_id #required
		add_index @@TABLENAME, :organism_id #required
		
		puts "#{@@TABLENAME} for pfam has been migrated."
		puts "In case you used scaffolding: Remember to activate your AQuA components setting activate: true".yellow
	end
	
	# destroy tables here
	def down
		drop_table @@TABLENAME
		puts "#{@@TABLENAME} for  pfam  has been rolled back."
		puts "Remember to de-activate your AQuA components setting activate: false".red
	end

end