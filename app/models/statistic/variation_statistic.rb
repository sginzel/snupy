class VariationStatistic < Statistic
	belongs_to :variation, foreign_key: :record_id, foreign_type: :variation
	attr_accessible :variation_id
	
	def variation_id()
		read_attribute(:record_id)
	end
	
	def variation_id=(newval)
		write_attribute(:record_id, newval)
	end
	
end