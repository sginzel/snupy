class GeneReportTemplate < ReportTemplate
	
	def self.report_klass
		ReportEntity
	end
	
	def self.required_parameters(params)
		params.merge({
			gene_panel: GenericGeneList.pluck(:name)
		})
	end
	
	def report_klass
		self.class.report_klass
	end
	
	def default_attributes
		super.merge({
			identifier: "GeneReport",
			type: report_klass.name,
			xref_id: @entity.id,
			institution_id: @entity.institution.id,
			filename: "GeneReport_#{@entity.name}.docx",
			mime_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
			description: "A Gene Report generated from a query result"
		})
	end
	
	# report_info = {
	#   variation_call_ids: [],
	#   panel_ids: []
	# }
	# RETURN: A text containnig the generated report
	def report_content(entity)
		@entity = entity
		generate_docx("app/views/reports/templates/gene_report.docx.erb", @report_params.merge({entity: entity}))
	end
	
	report_klass.register_template(self)
end
