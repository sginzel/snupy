class FilterSnpfEffGeneid < SimpleFilter
	create_filter_for QueryGeneId, :gene_id,
						name: :snp_eff_symbol, 
						label: "Symbol",
						filter_method: :symbol,
						checked: false,
						organism: [organisms(:human), organisms(:mouse)], 
						requires: {
							SnpEff => [:symbol]
						},
						tool: SnpEffAnnotation
						
		create_filter_for QueryGeneId, :gene_id_panel,
						name: :snpeff_symbol_list, 
						label: "Symbol, Ensembl Gene Id",
						filter_method: :snpeff_symbol_list,
						collection_method: :list_panels,
						checked: false,
						organism: [organisms(:human), organisms(:mouse)], 
						requires: {
							SnpEff => [:symbol, :ensembl_gene_id]
						},
						tool: SnpEffAnnotation
						
	create_filter_for QueryGeneFeature, :domain,
						name: :snp_eff_domain, 
						label: "Sequence Feature",
						filter_method: :domain,
						checked: false,
						organism: [organisms(:human), organisms(:mouse)], 
						requires: {
							SnpEff => [:annotation]
						},
						tool: SnpEffAnnotation
						
	def symbol(value)
		"snp_effs.symbol IN (#{value.join(",")})"
	end
	
	def snpeff_symbol_list(value)
		gene_lists = GenericGeneList.find_all_by_id(value)
		genes = gene_lists.map{|gl| gl.items.map{|gli| gli.value["gene"]}}.flatten.uniq
		genes.map!{|g| "'#{g}'"}
		"(snp_effs.symbol IN (#{genes.join(", ")})) OR (snp_effs.ensembl_gene_id IN (#{genes.join(", ")}))"
	end
	
	def domain(value)
		"snp_effs.annotation = 'sequence_feature'"
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