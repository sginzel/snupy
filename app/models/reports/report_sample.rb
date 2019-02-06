class ReportSample < Report
	
	belongs_to :sample, foreign_key: :xref_id
	
	def self.klass
		Sample
	end
	
	self.register_report()
	
end