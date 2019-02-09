class Report < ActiveRecord::Base
	include SnupyAgain::Utils
	
	belongs_to :user
	belongs_to :institution
	has_and_belongs_to_many :variation, :join_table  => 'report_has_variations'
	attr_accessible :content, :description, :identifier, :mime_type,
	                :name, :type, :filename, :xref_id,
	                :xref_klass, :user_id, :institution_id
	
	# the klass type should be checked before anything else
	before_validation :validate_klass
	before_validation :validate_type
	before_validation :validate_instance
	before_save :validate_name
	before_save :validate_identifier
	
	
	
	def self.register_template(klass)
		@templates << klass unless templates.include?(klass)
	end
	
	def self.templates
		@templates ||= []
	end
	
	def self.register_report
		klass.class_eval("has_many :reports, class_name: '#{self.name}', foreign_key: :xref_id")
	end
	
	def validate_name
		if self.name.nil? then
			self.name = self.type + "/" + self.klass.name + "#" + self.instance.id.to_s
		end
	end
	
	def validate_identifier
		if self.identifier.nil? then
			self.identifier = (Time.now.to_f * 1000).to_i.to_s(36)
		end
	end
	
	def validate_klass
		valid_klass_names = Report.subclasses.map(&:klass).map(&:name)
		# raise "not a valid klass (#{self.xref_klass.to_s})" unless
		if not valid_klass_names.include?(self.xref_klass.to_s) then
			errors.add(:xref_klass, "not valid")
		end
	end
	
	def validate_type
		myclass = Report.subclasses.select{|k| k.klass.name == self.xref_klass}.first
		raise "type is invalid(#{self.xref_klass})" if myclass.nil?
		self.type = myclass.name
	end
	
	def validate_instance
		begin
			self.instance # will raise a RecordNotFound in case xref_id does not exist for klass
		rescue ActiveRecord::RecordNotFound
			errors.add(:xref_id, "not valid")
		end
	end
	
	def content
		data = read_attribute(:content)
		begin
			data = Marshal.load( unzip(data) )
		rescue
		end
		data
	end
	
	# write the status of the object. This method also checks if the status to be set is valid.
	def content= (value)
		if value.is_a?ActionDispatch::Http::UploadedFile then
			self.mime_type = value.content_type
			self.filename = value.original_filename
			value = value.read
		elsif value.is_a?(File)
			self.mime_type = MIME::Types.type_for(value.path).first.content_type
			self.filename = File.basename value.path
			value = value.read
		elsif value.is_a?(StringIO)
			self.filename = value.hash.to_s(36).upcase
			value = value.read
		end
		dumped = Marshal.dump(value)
		write_attribute(:content, zip(dumped) )
	end
	
	def xref_id= (value)
		value = value.first if value.is_a?(Array)
		write_attribute(:xref_id, value )
	end
	
	def self.klass
		self.class
	end
	
	def klass
		Kernel.const_get(self.xref_klass)
	end
	
	def instance
		klass.find(self.xref_id)
	end

end
require_dependency 'reports/report_entity_group'
require_dependency 'reports/report_entity'
require_dependency 'reports/report_specimen_probe'
require_dependency 'reports/report_sample'
require_dependency 'reports/report_vcf_file'
