class CreateTagListItems < ActiveRecord::Migration
  def change
    create_table :tag_list_items do |t|
      t.string :name
      t.float :score
      t.string :strand
      t.references :region
      t.references :tag_list

      t.timestamps
    end
    add_index :tag_list_items, :region_id
    add_index :tag_list_items, :tag_list_id
  end
end
