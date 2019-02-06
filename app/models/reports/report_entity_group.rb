class ReportEntityGroup < Report
	belongs_to :entity_group, foreign_key: :xref_id
	def self.klass
		EntityGroup
	end
	self.register_report()
end