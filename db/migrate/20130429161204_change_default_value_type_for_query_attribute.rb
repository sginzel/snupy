class ChangeDefaultValueTypeForQueryAttribute < ActiveRecord::Migration
  def up
  	change_column(:query_filters, :default_value, :text, default: "", limit: 2048)
  end

  def down
  	change_column(:query_filters, :default_value, :string, default: "")
  end
end
