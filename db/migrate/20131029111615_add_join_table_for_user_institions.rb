class AddJoinTableForUserInstitions < ActiveRecord::Migration
  def change
  	create_table :institution_has_users do |t|
			t.references :user
			t.references :institution
		end
		add_index :institution_has_users, :user_id
		add_index :institution_has_users, :institution_id
		add_index :users, :name, unique: true ## this is to make sure the names are uniq
  end
end
