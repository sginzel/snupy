class CreateTagLists < ActiveRecord::Migration
  def change
    create_table :tag_lists do |t|
      t.string :name
      t.text :description
      t.string :tag_type
      t.string :tag_data_type
      t.string :filename

      t.timestamps
    end
    
    create_table :tag_list_has_users do |t|
    	t.references :tag_list
    	t.references :user
    end
    
    add_index :tag_list_has_users, :tag_list_id
    add_index :tag_list_has_users, :user_id
    
  end
end
