class AddMessageToEventlog < ActiveRecord::Migration
	def change
		add_column :event_logs, :messages, :text, array: true
		add_index :event_logs, :messages, length: 64
	end
end
