class AddMoreAttributesToVariationCall < ActiveRecord::Migration
	def change
		# CNV
		add_column :variation_calls, :cn, :float, default: nil # copy number
		add_column :variation_calls, :cnl, :float, default: nil # copy number likelihood
		
		add_column :variation_calls, :fs, :float, default: nil # fisher test for strand bias (phred score)
		
		add_index :variation_calls, :cn
		add_index :variation_calls, :cnl
		add_index :variation_calls, :fs
	end
end
