class FilterVepFeatures < SimpleFilter
	create_filter_for QueryGeneFeature, :motif,
						name: :vepmotif, 
						label: "JASPAR Motif(VEP)",
						filter_method: lambda{|val| "variation_annotations.motif_name IS NOT NULL"},
						organism: [organisms(:human)],
						checked: false,
						requires: {
							VariationAnnotation => [:motif_name]
						},
						tool: VariantEffectPredictorAnnotation,
						active: true
	create_filter_for QueryGeneFeature, :motif,
										name: :vepmotif,
										label: "JASPAR Motif (VEP) absolute score change > 0.05",
										filter_method: lambda{|val| "variation_annotations.motif_score_change > 0.05 OR variation_annotations.motif_score_change < -0.05"},
										organism: [organisms(:human)],
										checked: false,
										requires: {
												VariationAnnotation => [:motif_name]
										},
										tool: VariantEffectPredictorAnnotation,
										active: true
end