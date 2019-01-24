class CreateVariationTags < ActiveRecord::Migration
  def change
    create_table :variation_tags do |t|
      t.string :tag_name, null: false
      t.string :tag_value, null: false, limit: 2048
			t.string :tag_type, null: false
			
      t.timestamps
    end
    
    create_table :variation_has_variation_tag do |t|
			t.references :variation
			t.references :variation_tag
		end
  end
end
