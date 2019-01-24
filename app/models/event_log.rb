class EventLog < ActiveRecord::Base
	include SnupyAgain::Utils
	
	attr_accessible :category, :data, :name, :error, :started_at, :finished_at, :duration, :identifier
	
	def data
		yml = read_attribute(:data)
		begin
			ret = YAML.load( yml )
		end
		ret
	end
	
	# write the status of the object. This method also checks if the status to be set is valid.
	def data=(obj)
		dumped = YAML.dump(obj)
		write_attribute(:data, dumped )
	end
	
	def self.record(category = nil, &block)
		category = caller.first.split("/").last.split(":").first.camelcase if category.nil?
		event = EventLog.create(name: (Time.now.to_f*1000).to_i.to_s(36).upcase,
														identifier: Time.now.to_i.to_s(36).upcase,
														category: category,
														started_at: Time.now,
														duration: nil,
														error: nil,
														data: nil)
		begin
			ret = yield event
		rescue => e
			event.update_attribute(:error, [e.message, e.backtrace].join("\n"))
			raise e
		end
		event.finished_at = Time.now
		event.duration = (event.finished_at - event.started_at).to_f
		event.save
		return ret
	end

end
