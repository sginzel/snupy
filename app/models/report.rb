class Report < ActiveRecord::Base
	include SnupyAgain::Utils
	
	belongs_to :user
	belongs_to :institution
	has_and_belongs_to_many :variation, :join_table  => 'report_has_variations'
	attr_accessible :content, :description, :identifier, :mime_type,
	                :name, :type, :valid_until, :xref_id,
	                :xref_klass, :user_id, :institution_id
	
	# the klass type should be checked before anything else
	before_validation :validate_klass
	before_validation :validate_type
	before_validation :validate_instance
	before_save :validate_name
	before_save :validate_identifier
	
	
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
		raise "not a valid klass (#{self.xref_klass.to_s})" unless valid_klass_names.include?(self.xref_klass.to_s)
	end
	
	def validate_type
		myclass = Report.subclasses.select{|k| k.klass.name == self.xref_klass}.first
		raise "type is invalid" if myclass.nil?
		self.type = myclass.name
	end
	
	def validate_instance
		self.instance # will raise a RecordNotFound in case xref_id does not exist for klass
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
		pp value.yellow
		dumped = Marshal.dump(value)
		write_attribute(:content, zip(dumped) )
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
