class CreateSamples < ActiveRecord::Migration
  def change
    create_table :samples do |t|
      t.string :name, null: false
      t.string :patient, null: false
      t.text :notes
      t.string :contact
      t.string :gender, default: "unknown"
      t.boolean :ignorefilter, default: false
      t.references :vcf_file, null: false
      # t.references :experiment, null: false
			t.string :vcf_sample_name, null: false
			t.string :sample_type, null: false
      t.timestamps
    end
    
    add_index :samples, :vcf_file_id
    # add_index :samples, :experiment_id
    
    ## create n-m relationship table to users
    create_table :sample_has_users do |t|
			t.references :sample
			t.references :user
		end
    
    add_index :sample_has_users, :sample_id
    add_index :sample_has_users, :user_id
    
    ## create n-m relationship table to experiments
    create_table :sample_has_experiments do |t|
			t.references :sample
			t.references :experiment
		end
    
    add_index :sample_has_experiments, :sample_id
    add_index :sample_has_experiments, :experiment_id
  end
end
