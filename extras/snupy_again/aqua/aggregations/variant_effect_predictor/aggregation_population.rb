class AggregationPopulation < Aggregation
	register_aggregation :gmaf,
												label: "General Minor Allele Frequency",
												colname: "GMAF(VEP)",
												colindex: 10,
												aggregation_method: :gmaf,
												type: :attribute,
												checked: false,
												category: "Variant Effect Predictor",
												requires: {
													VariationAnnotation => [:gmaf]
												},
												active: false
	def gmaf(rec)
		"#{rec["variation_annotations.gmaf"]}"
	end
end