class ChangeSizeOfStatisticResults < ActiveRecord::Migration
    def up
  	change_column(:statistics, :value, :binary, limit: 128.megabyte)
  end

  def down
  	change_column(:statistics, :value, :binary)
  end
end
