class CreateSampleTags < ActiveRecord::Migration
  def change
    create_table :sample_tags do |t|
      t.string :tag_name, null: false
      t.text :tag_value, null: false
      t.string :tag_type, null: false

      t.timestamps
    end
    
    ## create n-m relationship table
    create_table :sample_has_sample_tag do |t|
			t.references :sample
			t.references :sample_tag
		end
  end
end
