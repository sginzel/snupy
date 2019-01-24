class AddIdentiferToEventLogs < ActiveRecord::Migration
	def change
		add_column :event_logs, :identifier, :string
		add_index :event_logs, :identifier
	end
end
