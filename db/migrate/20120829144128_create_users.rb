class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :name, null: false, uniq: true
      t.string :full_name
      t.boolean :is_admin
      t.string :email

      t.timestamps
    end
  end
end
