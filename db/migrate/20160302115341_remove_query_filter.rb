class RemoveQueryFilter < ActiveRecord::Migration
  def up
  	if table_exists?(:query_filters) then
  		drop_table :query_filters
  	end
  end

  def down
  	create_table :query_filters do |t|
      t.string :do_not_use, null: false
      t.timestamps
    end
  end
end
