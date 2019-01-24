class SampleStatistic < Statistic
	belongs_to :sample, foreign_key: :record_id, foreign_type: :sample
	attr_accessible :sample_id
	
	def sample_id()
		read_attribute(:record_id)
	end
	
	def sample_id=(newval)
		write_attribute(:record_id, newval)
	end
	
end