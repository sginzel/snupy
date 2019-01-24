class ExperimentHasAndBelongsToManyLongJobs < ActiveRecord::Migration
  def change
  	create_table :experiment_has_long_jobs do |t|
			t.references :experiment
			t.references :long_job
		end
		add_index :experiment_has_long_jobs, :experiment_id
		add_index :experiment_has_long_jobs, :long_job_id
  end
end
