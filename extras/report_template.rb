class ReportTemplate
	
	def self.report_klass
		raise "not implemented"
	end
	
	def self.required_parameters(params)
		params.merge({})
	end
	
	def report_klass
		self.class.report_klass
	end
	
	def initialize(report_params)
		@report_params = report_params
	end
	
	def default_attributes()
		{
			identifier: "Report",
			type: report_klass.name,
			xref_klass: report_klass.klass.name,
			description: "Some kind of report."
		}
	end
	
	def generate_report(klass_instance)
		
		content = report_content(klass_instance)
		attrs = default_attributes.merge({content: content, user_id: @report_params[:user_id]})
		report = report_klass.create(attrs)
		report.save!
		report
	end
	
	def generate_docx(template, locals)
		tmpfile = "tmp/#{Time.now.to_i.to_s(36).upcase}.docx"
		docx =Caracal::Document.new(tmpfile)
		#.render '/tmp/example.docx' do |docx|
		namespace = OpenStruct.new(locals.merge({docx: docx}))
		result = ERB.new(File.open(template){|f|f.read}).result(namespace.instance_eval { binding })
		docx.save
		ret = ""
		f = File.open(tmpfile, "r")
		begin
			ret = f.read
		ensure
			f.close
			File.unlink(f.path)
		end
		ret
	end
	
	private
	def self.load_templates
		Dir["extras/report_template/*.rb"].each do |f|
			require_dependency "report_template/#{File.basename(f,".rb")}"
		end
	end
end
ReportTemplate.load_templates
