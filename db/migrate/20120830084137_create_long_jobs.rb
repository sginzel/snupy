class CreateLongJobs < ActiveRecord::Migration
	def change
		create_table :long_jobs do |t|
			t.references :delayed_job
			t.string :title
			t.string :user
			t.string :handle
			t.string :method
			t.text :parameter
			t.column :result, :binary
			t.string :result_view
			t.string :status
			t.string :status_view
			t.datetime :started_at
			t.datetime :finished_at
			t.boolean :success
			t.string :checksum
			t.text :error

			t.timestamps
		end
	end
end
