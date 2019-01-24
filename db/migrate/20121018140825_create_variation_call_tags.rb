class CreateVariationCallTags < ActiveRecord::Migration
  def change
    create_table :variation_call_tags do |t|
      t.string :tag_name, null: false
      t.string :tag_value, null: false, limit: 2048
			t.string :tag_type, null: false
			
      t.timestamps
    end
    
    create_table :variation_call_has_variation_call_tag do |t|
			t.references :variation_call
			t.references :variation_call_tag
		end
  end
end
