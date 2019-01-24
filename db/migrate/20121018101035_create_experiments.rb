class CreateExperiments < ActiveRecord::Migration
  def change
    create_table :experiments do |t|
      t.string :name
      t.string :title
      t.string :contact
      t.string :description
			t.references :institution
			
      t.timestamps
    end
    add_index :experiments, :institution_id
    ## add n-m relation to user
    create_table :experiment_has_user do |t|
			t.references :user
			t.references :experiment
		end
		add_index :experiment_has_user, :user_id
		add_index :experiment_has_user, :experiment_id
  end
end
