class FilterCadd < SimpleFilter
	# filter_method can be a symbol for a method
	#               or a lambda: lambda{|value| "some_model_column IN (#{value.join(",")})"}
	create_filter_for QueryCadd, :query_cadd,
					  name: :cadd_phred_score,
					  label: "Phred Score (default)",
					  filter_method: lambda{|value| "#{Cadd.aqua_table_alias}.phred >= #{value} OR #{Cadd.table_name}.phred IS NULL"},
					  collection_method: nil,
					  organism: [organisms(:human)],
					  checked: false,
					  requires: {
						  Cadd => [:phred]
					  },
					  tool: Cadd
	create_filter_for QueryCadd, :query_cadd,
										name: :cadd_raw_score,
										label: "RAW Score (only use this if you have a reason)",
										filter_method: lambda{|value| "#{Cadd.aqua_table_alias}.raw >= #{value} OR #{Cadd.table_name}.raw IS NULL"},
										collection_method: nil,
										organism: [organisms(:human)],
										checked: false,
										requires: {
												Cadd => [:raw]
										},
										tool: Cadd

end
