class ClinvarEvidence < ActiveRecord::Base
	@@CLINVARCONFIG          = YAML.load_file(File.join(Aqua.annotationdir ,"clinvar", "clinvar_config.yaml"))[Rails.env]
	@@EVIDENCETABLENAME       = "clinvar_evidence#{@@CLINVARCONFIG["version"].to_s.gsub(".", "_")}s".to_sym # there is a pending s to be confirm with RAILS pluralized table form
	
	self.table_name = @@EVIDENCETABLENAME
	
	# optional, but handy associations
	belongs_to :variation
	belongs_to :organism
	has_one :alteration, through: :variation
	has_one :region, through: :variation
	has_many :variation_calls, foreign_key: :variation_id, primary_key: :variation_id
	has_many :samples, through: :variation_calls
	has_many :users, through: :samples
	has_many :experiments, through: :samples

	belongs_to :clinvar_evidence, primary_key: :clinsigincl_alleleid, foreign_key: :alleleid
	
	# list all attributes here to mass-assign them
	attr_accessible :variation_id,
	                :organism_id,
	                :alleleid,
	                :clndn,
									:geneinfo,
	                :clndnincl,
	                :clnhgvs,
	                :clnrevstat,
	                :clnsig,
	                :clnsigconf,
	                :origin,
	                :clnsigincl,
	                :clnsigincl_alleleid,
	                :clnsigincl_clnsig
	
	# optional method in case you want to do inheritance
	def self.aqua_table_alias
		self.table_name
	end

	def self.parse_clinvar_record(clininfo, variation_id)
		attrs = {
				:variation_id => variation_id,
				:organism_id => Aqua.organisms(:human).id
		}
		ClinvarEvidence.attribute_names.each do |attr|
			attrs[attr] = clininfo[attr.upcase]
			attrs[attr] = attrs[attr].to_i if attr.upcase == "ORIGIN"
		end
		if !attrs["clnsigincl"].nil? then
			attrs["clnsigincl_alleleid"] = attrs["clnsigincl"].split(":")[0]
			attrs["clnsigincl_clnsig"]   = attrs["clnsigincl"].split(":")[1]
		end
		attrs["clndn"].gsub!(",",";") unless attrs["clndn"].nil?
		attrs
	end

	def self.create_new_from_record(clininfo, variation_id)
		ClinvarEvidence.create(parse_clinvar_record(clininfo, variation_id))
	end

end

