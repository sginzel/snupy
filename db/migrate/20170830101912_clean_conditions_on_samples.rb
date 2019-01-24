class CleanConditionsOnSamples < ActiveRecord::Migration
	def up
		change_column :samples, :sample_type, :string, :null => true
		change_column :samples, :patient, :string, :null => true
	end

	def down
		change_column :samples, :sample_type, :string, :null => false
		change_column :samples, :patient, :string, :null => false
	end
end
