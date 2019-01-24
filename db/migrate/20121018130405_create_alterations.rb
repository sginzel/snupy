class CreateAlterations < ActiveRecord::Migration
  def change
    create_table :alterations do |t|
      t.string :ref, null: false, limit: 2048
      t.string :alt, null: false, limit: 2048
      t.string :alttype, null: false

      t.timestamps
    end
  end
end
