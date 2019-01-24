## == Description
# This is and auto generated model. See https://github.com/collectiveidea/delayed_job for more information
# == Attributes
#   [priority]
#   [attempts]
#   [handler]
#   [last_error]
#   [run_at]
#   [locked_at]
#   [failed_at]
#   [locked_by]
#   [queue]
#   [created_at]
#   [updated_at]
class DelayedJob < ActiveRecord::Base

  attr_accessible :priority, :attempts, :handler, :last_error, :run_at, :locked_at, :failed_at, :locked_by, :queue, :created_at, :updated_at

	before_destroy :deactivate_long_job

	def deactivate_long_job
		lj = LongJob.find_by_delayed_job_id(self.id)
		if !lj.nil? then
			lj.delayed_job_id = nil
			lj.status = "REMOVED"
			lj.success = false
			lj.error = lj.error.to_s + ": Delayed job removed from JobQueue at #{Time.now.to_s}"
			lj.save
		end
	end

end