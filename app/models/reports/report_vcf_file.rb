class ReportVcfFile < Report
	belongs_to :vcf_file, foreign_key: :xref_id
	def self.klass
		VcfFile
	end
	self.register_report()
end