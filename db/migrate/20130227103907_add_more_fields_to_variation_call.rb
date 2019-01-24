class AddMoreFieldsToVariationCall < ActiveRecord::Migration
  def change
    add_column :variation_calls, :ref_reads, :integer, default: -1
    add_column :variation_calls, :alt_reads, :integer, default: -1
  end
end
