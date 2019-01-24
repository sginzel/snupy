class VepGeneIds < SimpleFilter
	create_filter_for QueryGeneId, :gene_id,
						name: :_old_annotation_symbol,
						label: "Symbol",
						filter_method: :hgnc,
						organism: [organisms(:human), organisms(:mouse)], 
						checked: false,
						requires: {
							VariationAnnotation => {
								GeneticElement => [:hgnc]
							}
						},
						tool: VariantEffectPredictorAnnotation,
						active: false
						
	create_filter_for QueryGeneId, :gene_id_panel,
						name: :_old_annotation_vep_symbol_list,
						label: "Symbol, Ensembl Gene Id",
						filter_method: :vep_symbol_list,
						collection_method: :list_panels,
						organism: [organisms(:human), organisms(:mouse)], 
						checked: false,
						requires: {
							VariationAnnotation => {
								GeneticElement => [:hgnc, :ensembl_gene_id]
							}
						},
						tool: VariantEffectPredictorAnnotation,
						active: false
						
	create_filter_for QueryGeneId, :gene_id, 
						name: :_old_annotation_ensg,
						label: "Ensembl Gene ID",
						filter_method: :ensembl_gene_id,
						organism: [organisms(:human), organisms(:mouse)], 
						checked: false,
						requires: {
							VariationAnnotation => {
								GeneticElement => [:ensembl_gene_id]
							}
						},
						tool: VariantEffectPredictorAnnotation,
						active: false
	
	## create as SQL condition - value is sanitizes and has surrounding ''
	def hgnc(value)
		"genetic_elements.hgnc IN (#{value.join(",")})"
	end
	
	def vep_symbol_list(value)
		gene_lists = GenericGeneList.find_all_by_id(value)
		genes = gene_lists.map{|gl| gl.items.map{|gli| gli.value["gene"]}}.flatten.uniq
		genes.map!{|g| "'#{g}'"}
		"(genetic_elements.hgnc IN (#{genes.join(", ")})) OR (genetic_elements.ensembl_gene_id IN (#{genes.join(", ")}))"
	end
	
	def ensembl_gene_id(value)
		"genetic_elements.ensembl_gene_id IN (#{value.join(",")})"
	end
	
	def list_panels(params)
		User.find(params[:user]).generic_gene_lists.map{|ggl|
			{
				id: ggl.id,
				name: ActionController::Base.helpers.sanitize(ggl.name),
				title: ActionController::Base.helpers.sanitize(ggl.title),
				description: ActionController::Base.helpers.sanitize(ggl.description),
				"#items" => ggl.items.count
			}
		}
	end
	
end