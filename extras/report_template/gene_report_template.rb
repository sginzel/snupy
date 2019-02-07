#module SnupyAgain
	#module ReportTemplate
		class GeneReportTemplate < ReportTemplate
			def self.report_klass
				ReportEntity
			end
			
			def default_attributes
				super.merge({
					identifier: "GeneReport",
					type: report_klass.name,
					description: "A Gene Report generated from a query result"
				})
			end
			
			# report_info = {
			#   variation_call_ids: [],
			#   panel_ids: []
			# }
			# RETURN: A text containnig the generated report
			def report_content(entity, report_params)
				["Report for #{entity.name}",
				 report_params.pretty_inspect.to_s
				].join"\n"
			end
			
			report_klass.register_template(self)
		end
	#end
#end