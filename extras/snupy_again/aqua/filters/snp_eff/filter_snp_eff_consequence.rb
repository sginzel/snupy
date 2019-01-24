class FilterSnpEffConsequence < SimpleFilter
	create_filter_for QueryConsequence, :consequence,
						name: :consequence, 
						label: "Consequence",
						filter_method: :consequence,
						collection_method: :find_consequences,
						organism: [organisms(:human), organisms(:mouse)], 
						checked: false,
						requires: {
							SnpEff => [:annotation]
						},
						tool: SnpEffAnnotation
	
	def consequence(value)
		"snp_effs.annotation IN (#{value.join(",")})"
	end
	
	def find_consequences(params)
		ret = SnpEff.uniq.pluck(:annotation).sort.map{|c|
			{
				id: c,
				label: c
			}
		}
		ret
	end
	
end