class FilterVepVariation < SimpleFilter
	create_filter_for QueryVariationId, :varid,
						name: :dbsnp, 
						label: "Existing variations (VEP)",
						filter_method: lambda{|vals| 
							vals.map{|val|
								"(variation_annotations.existing_variation RLIKE '.*#{val.gsub(/^'/, "").gsub(/'$/, "")}.*')"
							}.join(" OR ")
						},
						organism: [organisms(:human), organisms(:mouse)], 
						checked: false,
						requires: {
							VariationAnnotation => [:existing_variation]
						},
						tool: VariantEffectPredictorAnnotation,
						active: false
end