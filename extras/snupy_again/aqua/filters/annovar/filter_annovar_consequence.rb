class FilterAnnovarConsequence < SimpleFilter
	create_filter_for QueryConsequence, :consequence,
						name: :consequence, 
						label: "Consequence (Ensembl v75)",
						filter_method: :consequence,
						collection_method: :list_consequences,
						organism: [organisms(:human), organisms(:mouse)],
						checked: false, 
						requires: {
							Annovar => [:ensembl_annotation]
						},
						tool: AnnovarAnnotation
	create_filter_for QueryConsequence, :consequence,
						name: :consequence_refgene, 
						label: "Consequence (RefSeq)",
						filter_method: :consequence_refgene,
						collection_method: :list_consequences,
						organism: [organisms(:human), organisms(:mouse)],
						checked: false, 
						requires: {
							Annovar => [:refgene_annotation]
						},
						tool: AnnovarAnnotation
						
	create_filter_for QueryConsequence, :consequence,
						name: :consequence_contradicting, 
						label: "Contradicting Consequence(RefSeq vs. Ensembl)",
						filter_method: :consequence_contradicting,
						collection_method: :list_consequences,
						organism: [organisms(:human), organisms(:mouse)],
						checked: false, 
						requires: {
							Annovar => [:ensembl_annotation, :refgene_annotation]
						},
						tool: AnnovarAnnotation
	def consequence(value)
		"annovars.ensembl_annotation IN (#{value.join(",")})"
	end
	
	def consequence_refgene(value)
		"annovars.refgene_annotation IN (#{value.join(",")})"
	end
	
	def consequence_contradicting(value)
		"annovars.ensembl_annotation != annovars.refgene_annotation AND annovars.ensembl_annotation IN (#{value.join(",")}) AND annovars.refgene_annotation IN (#{value.join(",")})"
	end
	
	def list_consequences(params)
		ret = Annovar.uniq.pluck(:ensembl_annotation).reject(&:nil?).sort.map{|c|
			{
				id: c,
				label: c
			}
		}
		ret
	end
	
end