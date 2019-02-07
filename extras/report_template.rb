#module SnupyAgain
#	module ReportTemplate
		class ReportTemplate
			
			def self.report_klass
				raise "not implemented"
			end
			def report_klass
				self.class.report_klass
			end
			
			def default_attributes
				{
					identifier: "Report",
					type: report_klass.name,
					xref_klass: report_klass.klass.name,
					description: "Some kind of report."
				}
			end
			
			def generate_report(klass_instance, report_params, opts = {})
				attrs = opts.merge(default_attributes)
				attrs[:content] = report_content(klass_instance, report_params) if attrs[:content].nil?
				report_klass.create(attrs)
			end
			
			private
			def self.load_templates
				Dir["extras/report_template/*.rb"].each do |f|
					load(f)
				end
			end
		end
#	end
#end