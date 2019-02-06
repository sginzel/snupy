class ReportSpecimenProbe < Report
	belongs_to :specimen_probe, foreign_key: :xref_id
	def self.klass
		SpecimenProbe
	end
	self.register_report()
end