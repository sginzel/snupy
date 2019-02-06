class ReportEntity < Report
	
	belongs_to :entity, foreign_key: :xref_id
	
	def self.klass
		Entity
	end
	
	self.register_report()
	
end