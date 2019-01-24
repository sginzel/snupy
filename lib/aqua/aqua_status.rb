class AquaStatus < ActiveRecord::Base
	# load("lib/vep/vep.rb")
	AVAILABLE_TYPE = ["AquaStatusAnnotation", "AquaStatusQuery", "AquaStatusFilter", "AquaStatusAggregation"]
	attr_accessible :type, :value, :source, :xref_id, :category
	validates_inclusion_of :type, :in => AVAILABLE_TYPE	
	
	def self.get(category, source)
		asa = AquaStatus.find_or_initialize_by_type_and_category_and_source(self.name, category, source)
		asa.save! unless asa.persisted?
		asa
	end
	
	def self.set(category, source, value = nil)
		if value.nil? then
			asa = AquaStatus.find_or_initialize_by_type_and_category_and_source(self.name, category, source)
		else
			asa = AquaStatus.find_or_initialize_by_type_and_category_and_source_and_value(self.name, category, source, value)
		end
		asa.save! unless asa.persisted?
		asa
	end
	
end

class AquaStatusAnnotation < AquaStatus
	#has_and_belongs_to_many :vcf_files,
	#	join_table: :aqua_statuses, 
	#	association_foreign_key: "xrefid", 
	#	foreign_key: "id", 
	#	:conditions => ['aqua_statuses.type = ? AND aqua_statuses.status = ?', self.name, "vcf_files"]
	
	before_save :set_vcf_annotation_pending
	
	def set_vcf_annotation_pending
		# make sure this is the default when saving the status for the first time.
		if self.category == "vcf_file" and self.value.nil? then
			self.value = "PENDING"
		end
	end
	
	def vcf_file
		return nil if self.category != "vcf_file"
		return VcfFile.joins(:aqua_status_annotations).includes(:aqua_status_annotations).find(self.xref_id)
		# return VcfFile.find_without_data(self.xref_id)
	end
	
	def complete_annotation
		self.value = "OK"
		self.save!
		vcf = self.vcf_file
		if vcf.aqua_annotation_status.all?{|asa| asa.annotation_completed?} then
			vcf.status = "DONE"
			vcf.save!
		end
	end
	
	def revoke_annotation
		vcf = self.vcf_file
		vcf.status = "INCOMPLETE"
		vcf.save!
		self.value = "REVOKED"
		self.save!
	end
	
	def failed_annotation
		self.update_attribute(:value, "FAIL")
		#self.value = "FAIL"
		#self.save!
	end
	
	def not_applicable_annotation
		self.update_attribute(:value, "NOTAPPLICABLE")
		#self.value = "NOTAPPLICABLE"
		#self.save!
	end
	
	def annotation_completed?
		self.is_ok? || self.is_not_applicable?
	end
	def is_ok?
		self.value == "OK"
	end
	def is_not_applicable?
		self.value == "NOTAPPLICABLE"
	end
	def is_complete?
		#self.value == "OK"
		self.annotation_completed?
	end
	def is_incomplete?
		self.value == "INCOMPLETE"
	end
	def is_revoked?
		self.value == "REVOKED"
	end
	def is_pending?
		self.value == "PENDING"
	end

	def tool
		aname = self.source.split("/",2).first
		Aqua.annotations.keys.select{|t| t.name == aname}.first
	end
	
end

class AquaStatusQuery < AquaStatus
	
end

class AquaStatusFilter < AquaStatus
	
end

class AquaStatusAggregation < AquaStatus
	
end