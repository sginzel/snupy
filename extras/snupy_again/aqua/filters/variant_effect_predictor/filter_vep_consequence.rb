class FilterVepConsequence < SimpleFilter
	create_filter_for QueryConsequence, :consequence,
						name: :consequence, 
						label: "Consequence",
						filter_method: :consequence,
						collection_method: :find_consequences,
						organism: [organisms(:human), organisms(:mouse)],
						checked: false,
						requires: {
							VariationAnnotation => {
								Consequence => [:consequence]
							}
						},
						tool: VariantEffectPredictorAnnotation,
						active: false
	
	def consequence(value)
		"consequences.consequence IN (#{value.join(",")})"
	end
	
	def find_consequences(params)
		ret = Consequence.pluck(:consequence).sort.map{|c|
			{
				id: c,
				label: c
			}
		}
		ret
	end
	
end