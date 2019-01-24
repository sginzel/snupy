class FilterClinvar < SimpleFilter
	# filter_method can be a symbol for a method
	#               or a lambda: lambda{|value| "some_model_column IN (#{value.join(",")})"}
	create_filter_for QueryClinicalSignificance, :clinical_clinvar,
										name: :clndn,
										label: "Associated to phenotype",
										filter_method: lambda{|value| "#{Clinvar.table_name}.clndn IN (#{value.join(",")})"},
										collection_method: :find_possibilities, # this needs to be configured only once
										organism: [organisms(:human)],
										checked: true,
										requires: {
												Clinvar => [:clndn]
										},
										tool: ClinvarAnnotation,
										active: true
	create_filter_for QueryClinicalSignificance, :clinical_clinvar,
										name: :dist0,
										label: "Distance to ClinVar <= 0",
										filter_method: lambda{|value| FilterClinvar.distlt(0)},
										collection_method: :find_nothing, # this needs to be configured only once
										organism: [organisms(:human)],
										checked: false,
										requires: {
											Clinvar => [:distance]
										},
										tool: ClinvarAnnotation,
										active: true
	create_filter_for QueryClinicalSignificance, :clinical_clinvar,
										name: :dist10,
										label: "Distance to ClinVar <= 10",
										filter_method: lambda{|value| FilterClinvar.distlt(10)},
										collection_method: :find_nothing,
										organism: [organisms(:human)],
										checked: true,
										requires: {
												Clinvar => [:distance]
										},
										tool: ClinvarAnnotation,
										active: true
	create_filter_for QueryClinicalSignificance, :clinical_clinvar,
										name: :dist30,
										label: "Distance to ClinVar <= 30",
										filter_method: lambda{|value| FilterClinvar.distlt(30)},
										collection_method: :find_nothing,
										organism: [organisms(:human)],
										checked: false,
										requires: {
												Clinvar => [:distance]
										},
										tool: ClinvarAnnotation,
										active: true
	create_filter_for QueryClinicalSignificance, :clinical_clinvar,
										name: :dist100,
										label: "Distance to ClinVar <= 100",
										filter_method: lambda{|value| FilterClinvar.distlt(100)},
										collection_method: :find_nothing,
										organism: [organisms(:human)],
										checked: false,
										requires: {
												Clinvar => [:distance]
										},
										tool: ClinvarAnnotation,
										active: true
	create_filter_for QueryClinicalSignificance, :clinical_clinvar,
										name: :dist150,
										label: "Distance to ClinVar = 150",
										filter_method: lambda{|value| FilterClinvar.distlt(150)},
										collection_method: :find_nothing,
										organism: [organisms(:human)],
										checked: false,
										requires: {
												Clinvar => [:distance]
										},
										tool: ClinvarAnnotation,
										active: true

	create_filter_for QueryClinicalSignificance, :clinical_clinvar,
										name: :is_reviewed,
										label: "Reviewed/Expert Panel/Multiple Submitters",
										filter_method: lambda{|value| "#{Clinvar.table_name}.is_reviewed = 1"},
										collection_method: :find_nothing,
										organism: [organisms(:human)],
										checked: true,
										requires: {
												Clinvar => [:is_reviewed]
										},
										tool: ClinvarAnnotation,
										active: true

	create_filter_for QueryClinicalSignificance, :clinical_clinvar,
										name: :pathogenic,
										label: "Pathogenic",
										filter_method: lambda{|value| "#{Clinvar.table_name}.is_pathogenic = 1"},
										collection_method: :find_nothing,
										organism: [organisms(:human)],
										checked: false,
										requires: {
												Clinvar => [:is_pathogenic]
										},
										tool: ClinvarAnnotation,
										active: true

	create_filter_for QueryClinicalSignificance, :clinical_clinvar,
										name: :drug_response,
										label: "Drug response",
										filter_method: lambda{|value| "#{Clinvar.table_name}.is_drug_response = 1"},
										collection_method: :find_nothing,
										organism: [organisms(:human)],
										checked: false,
										requires: {
												Clinvar => [:is_drug_response]
										},
										tool: ClinvarAnnotation,
										active: true

	create_filter_for QueryClinicalSignificance, :clinical_clinvar,
										name: :risk_factor,
										label: "Risc factor",
										filter_method: lambda{|value| "#{Clinvar.table_name}.is_risk_factor = 1"},
										collection_method: :find_nothing,
										organism: [organisms(:human)],
										checked: false,
										requires: {
												Clinvar => [:is_risk_factor]
										},
										tool: ClinvarAnnotation,
										active: true

	create_filter_for QueryClinicalSignificance, :clinical_clinvar,
										name: :origin_germline,
										label: "Origin: Germline",
										filter_method: lambda{|value| "#{Clinvar.table_name}.origin_germline = 1"},
										collection_method: :find_nothing,
										organism: [organisms(:human)],
										checked: false,
										requires: {
												Clinvar => [:origin_germline]
										},
										tool: ClinvarAnnotation,
										active: true

	create_filter_for QueryClinicalSignificance, :clinical_clinvar,
										name: :origin_somatic,
										label: "Origin: Somatic",
										filter_method: lambda{|value| "#{Clinvar.table_name}.origin_somatic = 1"},
										collection_method: :find_nothing,
										organism: [organisms(:human)],
										checked: false,
										requires: {
												Clinvar => [:origin_somatic]
										},
										tool: ClinvarAnnotation,
										active: true

	create_filter_for QueryClinicalSignificance, :clinical_clinvar,
										name: :origin_denovo,
										label: "Origin: De-novo",
										filter_method: lambda{|value| "#{Clinvar.table_name}.origin_denovo = 1"},
										collection_method: :find_nothing,
										organism: [organisms(:human)],
										checked: false,
										requires: {
												Clinvar => [:origin_denovo]
										},
										tool: ClinvarAnnotation,
										active: true

	create_filter_for QueryClinicalSignificance, :clinical_clinvar,
										name: :no_conflict,
										label: "Not conflicting",
										filter_method: lambda{|value| "#{Clinvar.table_name}.is_conflicting = 0"},
										collection_method: :find_nothing,
										organism: [organisms(:human)],
										checked: true,
										requires: {
												Clinvar => [:is_conflicting]
										},
										tool: ClinvarAnnotation,
										active: true

	# return a SQL condition here.
	def self.distlt(value)
		"ABS(#{Clinvar.table_name}.distance) <= #{value}"
	end
	
	# in case of ComplexFilter - filter the array
	# def some_filter_method(arr, value)
	# 	arr.select{|rec| rec['some_attr'] == value}
	# end
	
	# returns a array of hashes containting
	def find_possibilities(params)
		pheno2gene = {}
		Clinvar.select([:clndn, :symbol])
				.where("clndn IS NOT NULL")
				.where("clndn != 'not_specified'")
				.where("clndn != 'not_provided'").each do |clv|
			pheno2gene[clv.clndn] ||= {id: clv.clndn, label: clv.clndn.gsub(";", ",").gsub("_", " "), genes: [clv.symbol]}
			pheno2gene[clv.clndn][:genes] << clv.symbol unless pheno2gene[clv.clndn][:genes].include?(clv.symbol)
		end
		pheno2gene.values.flatten
	end

	def find_nothing(params)
		[]
	end
	
	def applicable?(organismid = nil)
		is_applicable = super
		# this may be used to check if other models exist or not.
		# check_some_other_thing = !defined?(SomeOtherModel).nil? # example
		check_some_other_thing = true
		is_applicable && check_some_other_thing
	end
end
