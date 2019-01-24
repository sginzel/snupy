class CreateEventLogs < ActiveRecord::Migration
	def change
		create_table :event_logs do |t|
			t.string :name
			t.string :category
			t.string :data, limit: (16.megabytes - 1)
			t.string :error, limit: (16.megabytes - 1)
			t.timestamp :started_at
			t.timestamp :finished_at
			t.float :duration
			t.timestamps
		end
		add_index :event_logs, :name
		add_index :event_logs, :category
		add_index :event_logs, :started_at
		add_index :event_logs, :finished_at
		add_index :event_logs, :duration
		add_index :event_logs, :error, length: 128
		add_index :event_logs, :data, length: 128
	end
end
