class ReportTemplate
	
	attr_accessor :klass_instance, :report_params
	
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
		params = {}
		report_params.each do |k,v|
			if v =~ /^---.*/ then
				params[k] = YAML.load(v)
			else
				params[k] = v
			end
		end
		self.report_params = params
	end
	
	def default_attributes()
		{
			identifier: "Report",
			type: report_klass.name,
			xref_klass: report_klass.klass.name,
			description: "Some kind of report."
		}
	end
	
	def generate_report(klass_instance, update = true)
		self.klass_instance = klass_instance
		
		report = report_klass.where(default_attributes).first
		content = report_content(klass_instance)
		if !report then
			attrs = default_attributes.merge({content: content, user_id: report_params[:user_id]})
			report = report_klass.create(attrs)
		else
			if update then
				report.content = content
				report.user_id = report_params[:user_id]
			end
		end
		report.save!
		report
	end
	
	def generate_docx(template, locals)
		tmpfile = "tmp/#{Time.now.to_i.to_s(36).upcase}.docx"
		docx =Caracal::Document.new(tmpfile)
		#.render '/tmp/example.docx' do |docx|
		namespace = OpenStruct.new(locals.merge({docx: docx}))
		def namespace.method_missing(m, *args, &block)
			# find first attribute to respond to method
			attributes = self.table
			hit = attributes.keys.select{|k|
				self.table[k].respond_to?(m)
			}.first
			if hit
				self.table[hit].send(m, *args, &block)
			else
				super(m, *args, &block)
			end
		end
		docx.instance_variable_set("@_snupy_namespace", namespace)
		def docx.method_missing(m, *args, &block)
			if @_snupy_namespace.respond_to?(m) then
				@_snupy_namespace.send(m, *args, &block)
			else
				super
			end
		end
		template = File.open(template){|f|f.read}
		result = ERB.new("<%@docx=docx;#{template}%>").result(namespace.instance_eval { binding })
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
