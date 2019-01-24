class RemoveTagList < ActiveRecord::Migration
	def up
		drop_table :tag_lists if table_exists? :tag_lists
		drop_table :tag_list_items if table_exists? :tag_list_items
		drop_table :tag_list_has_users if table_exists? :tag_list_has_users
	end

	def down
	end
end
