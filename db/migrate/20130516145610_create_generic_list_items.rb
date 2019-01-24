class CreateGenericListItems < ActiveRecord::Migration
  def change
    create_table :generic_list_items do |t|
      t.text :value, limit: 1.kilobyte
      t.string :type, default: "GenericListItem"
      t.references :generic_list, null: false

      t.timestamps
    end
    add_index :generic_list_items, :generic_list_id
    add_index :generic_list_items, :value, length: 1024
    add_index :generic_list_items, :type
  end
end
