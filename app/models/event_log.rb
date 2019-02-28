class EventLog < ActiveRecord::Base
	include SnupyAgain::Utils
	
	attr_accessible :category, :data, :name, :error, :started_at,
	                :finished_at, :duration, :identifier, :messages
	
	after_initialize :load_messages
	
	def load_messages
		if self.messages.nil? then
			self.messages = []
		else
			self.messages = YAML.load(read_attribute(:messages))
		end
		self.messages
	end
	
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
			ret = block.call(event)
		rescue => e
			event.update_attribute(:error, [e.message, e.backtrace].join("\n"))
			raise e
		end
		event.finished_at = Time.now
		event.duration = (event.finished_at - event.started_at).to_f
		event.save
		return ret
	end
	
	def add_message(msg)
		msg = [msg] unless msg.is_a?(Array)
		msg.each do |txt|
			self.messages << txt
		end
		self.update_attribute(:messages, self.messages.to_yaml)
		self.load_messages
	end
	
	def to_s
		"EventLog(##{self.id})-#{self.name}.#{self.category}.#{self.duration}"
	end
	
end
