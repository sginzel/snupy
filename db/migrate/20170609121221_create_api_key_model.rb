class CreateApiKeyModel < ActiveRecord::Migration
  def change
		create_table :api_keys do |t|
			t.references :user
			t.string :token, size: 1024
			t.timestamps
		end
		
		add_index :api_keys, :user_id
		add_index :api_keys, :token
  end
end
