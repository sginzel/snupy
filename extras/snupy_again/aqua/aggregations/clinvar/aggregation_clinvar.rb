class AggregationClinvar < Aggregation
	# provide all attributes of a model through the AQuA API
	# batch_attributes(Clinvar)
	
	
	register_aggregation :aggregation_clinvar,
						 label: "ClinVar CLNDN",
						 colname: "Clinvar",
						 colindex: 3,
						 aggregation_method: :clndn,
						 type: :attribute,
						 checked: true,
						 category: :clinvar,
						 requires: {
							 Clinvar => [:clndn, :distance, :symbol,:is_pathogenic,:is_drug_response,:alleleid,:is_protective,:is_risk_factor]
						 },
						 color: {
								 "Clinvar[pathogenic]" => Aqua.color_bool(),
								 "Clinvar[drug_response]" => Aqua.color_bool(),
								 "Clinvar[protective]" => Aqua.color_bool(),
								 "Clinvar[risk_factor]" => Aqua.color_bool(),
								 "Clinvar[distance]" => create_color_gradient([-150, -15,0, 15,150], colors = ["palegreen", "lightyellow", "salmon", "lightyellow", "palegreen"]),
						 },
						 record_color: {
								 "Clinvar[symbol]" => :factor_norm
						 },
						 active: true # use this to activate your query once it is ready
	
	register_aggregation :aggregation_clinvar1,
						 label: "Some other label",
						 colname: "Some other attr",
						 colindex: 3.1,
						 aggregation_method: lambda{|rec|
							rec["some_attribute"]
						 },
						 type: :attribute,
						 record_color: {
							 "Some other attr" => :factor
						 },
						 checked: true,
						 category: :clinvar,
						 requires: {
							 Clinvar => ["some_attribute"]
						 },
						 active: false # use this to activate your query once it is ready
	
	def clndn(rec)
		{
			clndn: linkout(
				label: rec["#{Clinvar.table_name}.clndn"],
				url: {
						"ClinVar" => "https://www.ncbi.nlm.nih.gov/clinvar?term=#{rec["#{Clinvar.table_name}.alleleid"]}[AlleleID]",
						"GeneCards" => "http://www.genecards.org/cgi-bin/carddisp.pl?gene=#{rec["#{Clinvar.table_name}.symbol"]}"
				}
			),
			distance: rec["#{Clinvar.table_name}.distance"],
			symbol: rec["#{Clinvar.table_name}.symbol"],
			pathogenic: rec["#{Clinvar.table_name}.is_pathogenic"],
			drug_response: rec["#{Clinvar.table_name}.is_drug_response"],
			protective: rec["#{Clinvar.table_name}.is_protective"],
			risk_factor: rec["#{Clinvar.table_name}.is_risk_factor"]
		}

	end

end