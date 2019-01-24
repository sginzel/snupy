class ChangeResultSizeForLongJobs < ActiveRecord::Migration
  def up
  	change_column(:long_jobs, :result, :binary, limit: 100.megabyte)
  end

  def down
  	change_column(:long_jobs, :result, :binary)
  end
end
