class ChangeLongJobHandleToText < ActiveRecord::Migration
  def up
  	change_column(:long_jobs, :handle, :text)
  end

  def down
  	change_column(:long_jobs, :handle, :string)
  end
end
