class AddQueueToLongJobs < ActiveRecord::Migration
  def change
    add_column :long_jobs, :queue, :string, default: "snupy"
  end
end
