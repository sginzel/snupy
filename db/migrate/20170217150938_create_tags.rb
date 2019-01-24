class CreateTags < ActiveRecord::Migration
	def up
		create_table :tags do |t|
			t.string :object_type, null: false
			t.string :category, null: false
			t.string :subcategory, default: nil
			t.string :value, limit: 512, null: false
			t.string :description, limit: 2048, default: nil

			t.timestamps
		end
		
		create_table :tag_has_objects do |t|
			t.references :tag
			t.string :object_type
			t.integer :object_id
		end
		
		add_index :tags, :object_type
		add_index :tags, :category
		add_index :tags, :subcategory
		add_index :tags, :value
		add_index :tags, :description
		add_index :tags, [:object_type, :category, :subcategory, :value], name: "unique_ot_cat_subcat_val", unique: true, length: 32
		
		add_index :tag_has_objects, :tag_id
		add_index :tag_has_objects, :object_type
		add_index :tag_has_objects, :object_id
		add_index :tag_has_objects, [:tag_id, :object_id]
		add_index :tag_has_objects, [:tag_id, :object_type]
		add_index :tag_has_objects, [:object_id, :object_type]
	 
		# initialize tags here
		Tag.transaction do 
			Dir["db/tags/*"].each do |file|
				next unless file =~ /.yaml$/ or file =~ /.csv$/
				d "adding tags from #{file}"
				if file =~ /.csv$/ then
					object_type = File.basename file, ".csv"
					records = []
					header = nil
					File.open(file, "r").each_line do |line|
						line.strip!
						next if line[0] == "#"
						next if line == ""
						cols = line.split("\t")
						if header.nil?
							header = cols
							next
						end 
						records << Hash[header.each_with_index.map{|h, i|[h, cols[i]]}]
					end
				else
					object_type = File.basename file, ".yaml"
					records = YAML.load(File.read(file))
					next unless records
				end
				object_type, category = object_type.split("_", 2)
				records.each do |rec|
					Tag.create ({"object_type" => object_type, "category" => category.to_s.upcase}).merge(rec)
				end
			end
		end
	end
	
	def down
		drop_table :tag_has_objects
		drop_table :tags
	end
end
