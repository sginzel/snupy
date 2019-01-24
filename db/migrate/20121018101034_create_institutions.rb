class CreateInstitutions < ActiveRecord::Migration
  def change
    create_table :institutions do |t|
      t.string :name
      t.string :contact
      t.string :email
      t.string :phone

      t.timestamps
    end
  end
end
