class CreateGenericLists < ActiveRecord::Migration
  def change
    create_table :generic_lists do |t|
      t.string :name
      t.string :title
      t.text :description
      t.string :type

      t.timestamps
    end
    
    create_table :generic_list_has_users do |t|
    	t.references :generic_list
    	t.references :user
    end
    
    add_index :generic_list_has_users, :generic_list_id
    add_index :generic_list_has_users, :user_id
  end
end
