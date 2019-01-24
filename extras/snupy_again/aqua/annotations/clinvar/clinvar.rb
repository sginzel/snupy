class Clinvar < ActiveRecord::Base
	@@CLINVARCONFIG = YAML.load_file(File.join(Aqua.annotationdir, "clinvar", "clinvar_config.yaml"))[Rails.env]
	@@CLINVARTABLENAME = "clinvar#{@@CLINVARCONFIG["version"].to_s.gsub(".", "_")}s".to_sym # there is a pending s to be confirm with RAILS pluralized table form
	@@EVIDENCETABLENAME = "clinvar_evidence#{@@CLINVARCONFIG["version"].to_s.gsub(".", "_")}s".to_sym # there is a pending s to be confirm with RAILS pluralized table form

	self.table_name = @@CLINVARTABLENAME

	# optional, but handy associations
	belongs_to :variation
	belongs_to :organism
	has_one :alteration, through: :variation
	has_one :region, through: :variation
	has_many :variation_calls, foreign_key: :variation_id, primary_key: :variation_id
	has_many :samples, through: :variation_calls
	has_many :users, through: :samples
	has_many :experiments, through: :samples

	belongs_to :clinvar_evidence

	# list all attributes here to mass-assign them
	attr_accessible :variation_id,
									:organism_id,
									:clinvar_evidence_id,
									:is_reviewed,
									:alleleid,
									:distance,
									:allele_match,
									:symbol,
									:geneid,
									:clndn,
									:is_pathogenic,
									:is_likely_benign,
									:is_benign,
									:is_likely_pathogenic,
									:is_drug_response,
									:is_association,
									:is_risk_factor,
									:is_protective,
									:is_uncertain_significance,
									:is_other_significance,
									:is_not_provided,
									:is_conflicting,
									:origin_unknown,
									:origin_germline,
									:origin_somatic,
									:origin_inherited,
									:origin_parental,
									:origin_maternal,
									:origin_denovo,
									:origin_biparental,
									:origin_uniparental,
									:origin_nottested,
									:origin_inconclusive

	def self.parse_evidence(evidence, distance, variation_id, allele_match)
		##INFO=<ID=ORIGIN,Number=.,Type=String,Description="Allele origin. One or more of the following values may be added:
		# 0 - unknown; 1 - germline; 2 - somatic; 4 - inherited;
		# 8 - paternal; 16 - maternal; 32 - de-novo;
		# 64 - biparental; 128 - uniparental; 256 - not-tested;
		# 512 - tested-inconclusive; 1073741824 - other">
		attrs = []
		attrs_template = {
				:variation_id               => variation_id,
				:organism_id                => Aqua.organisms(:human).id,
				:clinvar_evidence_id        => evidence.id,
				:alleleid                   => evidence.alleleid,
				:distance                   => distance,
				:allele_match               => allele_match,
				:is_conflicting            => !evidence.clnsigconf.nil?
		}
		attrs_template = attrs_template.merge({
				:symbol                     => evidence.geneinfo.to_s.split("|").first.split(":")[0], # only consider the first gene in list
				:geneid                     => evidence.geneinfo.to_s.split("|").first.split(":")[1], # it seems to be handled this way in the web interface too
		}) unless evidence.geneinfo.nil?
		attrs_template = attrs_template.merge({
				:is_pathogenic              => !evidence.clnsig.index("Pathogenic").nil?,
				:is_likely_pathogenic       => !evidence.clnsig.index("Likely_pathogenic").nil?,
				:is_likely_benign           => !evidence.clnsig.index("Likely_benign").nil?,
				:is_benign                  => !evidence.clnsig.index("Benign").nil?,
				:is_drug_response           => !evidence.clnsig.index("drug_response").nil?,
				:is_association             => !evidence.clnsig.index("association").nil?,
				:is_risk_factor             => !evidence.clnsig.index("risk_factor").nil?,
				:is_protective              => !evidence.clnsig.index("protective").nil?,
				:is_uncertain_significance  => !evidence.clnsig.index("Uncertain_significance").nil?,
				:is_other_significance      => !evidence.clnsig.index("other").nil?,
				:is_not_provided            => !evidence.clnsig.index("not_provided").nil?
			}) unless evidence.clnsig.nil?
		attrs_template = attrs_template.merge({
				:is_reviewed                => !evidence.clnrevstat.index("reviewed_by_expert_panel").nil? ||
				                               !evidence.clnrevstat.index("criteria_provided,_conflicting_interpretations").nil? ||
				                               !evidence.clnrevstat.index("practice_guideline").nil?
		}) unless evidence.clnrevstat.nil?
		attrs_template = attrs_template.merge({
			:origin_unknown             => evidence.origin.to_i == 0,
			:origin_germline            => evidence.origin.to_i & 1 == 1,
			:origin_somatic             => evidence.origin.to_i & 2 == 2,
			:origin_inherited           => evidence.origin.to_i & 4 == 4,
			:origin_parental            => evidence.origin.to_i & 8 == 8,
			:origin_maternal            => evidence.origin.to_i & 16 == 16,
			:origin_denovo              => evidence.origin.to_i & 32 == 32,
			:origin_biparental          => evidence.origin.to_i & 64 == 64,
			:origin_uniparental         => evidence.origin.to_i & 128 == 128,
			:origin_nottested           => evidence.origin.to_i & 256 == 256,
			:origin_inconclusive        => evidence.origin.to_i & 1073741824 == 1073741824
		}) unless evidence.origin.nil?
		if !evidence.clndn.nil? then
			evidence.clndn.to_s.split("|").uniq.each do |clndn|
				attr = attrs_template.dup
				attr[:clndn] = clndn.gsub(",", ";")
				attrs << attr
			end
		else
			attrs << attrs_template.dup
		end
		attrs
	end

	def self.create_from_evidence(evidence, distance, variation_id, allele_match)
		parse_evidence(evidence, distance, variation_id, allele_match).map do |attr|
			Clinvar.create(attr)
		end
	end

	# optional method in case you want to do inheritance
	def self.aqua_table_alias
		self.table_name
	end

	def self.local_vcf_file
		ClinvarAnnotation.local_vcf_file
	end

	def self.vcf_file
		ClinvarAnnotation.vcf_file
	end

end

