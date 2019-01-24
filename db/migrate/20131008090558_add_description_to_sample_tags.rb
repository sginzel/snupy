class AddDescriptionToSampleTags < ActiveRecord::Migration
  def change
  	add_index :sample_tags, [:tag_name, :tag_type, :tag_value], unique: true, length: 128
  	add_column :sample_tags, :description, :text, default: ""
  end
end
