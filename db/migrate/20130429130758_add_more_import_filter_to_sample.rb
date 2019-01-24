class AddMoreImportFilterToSample < ActiveRecord::Migration
  def change
  	add_column :samples, :min_read_depth, :integer, default: 0
  	add_column :samples, :info_matches, :text, default: ""
  	add_column :samples, :status, :string, default: "CREATED"
  end
end
