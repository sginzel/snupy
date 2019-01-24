class FilterStringInteraction < SimpleFilter
	create_filter_for QueryInteraction, :gene_interaction,
						name: :ppi900, 
						label: "900 - STRING 9.1 (highest confidence, VEP gene)",
						filter_method: :ppi900,
						organism: [organisms(:human), organisms(:mouse)], 
						checked: true,
						requires: {
							Vep::Ensembl => [:gene_id, :gene_symbol]
						},
						tool: VepAnnotation
		create_filter_for QueryInteraction, :gene_interaction,
						name: :ppi700, 
						label: "700 - STRING 9.1 (high confidence, VEP gene)",
						filter_method: :ppi700,
						organism: [organisms(:human), organisms(:mouse)], 
						checked: false,
						requires: {
							Vep::Ensembl => [:gene_id, :gene_symbol]#,
							#StringProteinLink => [:stringdb1_id, :stringdb1_id, :combined_score],
							#StringProtein => [:stringdb_id],
							#StringProteinAliasName => [:stringdb_id, :alias]
						},
						tool: VepAnnotation
		create_filter_for QueryInteraction, :gene_interaction,
						name: :ppi400, 
						label: "400 - STRING 9.1 (medium confidence, VEP gene)",
						filter_method: :ppi400,
						organism: [organisms(:human), organisms(:mouse)], 
						checked: false,
						requires: {
							Vep::Ensembl => [:gene_id, :gene_symbol]#,
							#StringProteinLink => [:stringdb1_id, :stringdb1_id, :combined_score],
							#StringProtein => [:stringdb_id],
							#StringProteinAliasName => [:stringdb_id, :alias]
						},
						tool: VepAnnotation
		create_filter_for QueryInteraction, :gene_interaction,
						name: :ppi150, 
						label: "150 - STRING 9.1 (lowest confidence, VEP gene)",
						filter_method: :ppi150,
						organism: [organisms(:human), organisms(:mouse)], 
						checked: false,
						requires: {
							Vep::Ensembl => [:gene_id, :gene_symbol]#,
							#StringProteinLink => [:stringdb1_id, :stringdb1_id, :combined_score],
							#StringProtein => [:stringdb_id],
							#StringProteinAliasName => [:stringdb_id, :alias]
						},
						tool: VepAnnotation
		
			create_filter_for QueryInteraction, :gene_interaction_panel,
						name: :ppi900_panel, 
						label: "900 - STRING 9.1 (highest confidence, VEP gene)",
						filter_method: :ppi900_panel,
						collection_method: :list_panels,
						organism: [organisms(:human), organisms(:mouse)],
						checked: true, 
						requires: {
							Vep::Ensembl => [:gene_id, :gene_symbol]#,
							#StringProteinLink => [:stringdb1_id, :stringdb1_id, :combined_score],
							#StringProtein => [:stringdb_id],
							#StringProteinAliasName => [:stringdb_id, :alias]
						},
						tool: VepAnnotation
	
	## create as SQL condition - value is sanitizes and has surrounding ''
	def find_links(genes, opts, combined_score)
		organism_id = Experiment.find((opts[:experiment] || opts["experiment"])).organism_id
		stringids = StringProteinAliasName.where(organism_id: organism_id)
																			.where(alias: genes.map{|g| g.gsub(/^'/, "").gsub(/'$/, "")})
																			.pluck("stringdb_id").uniq
		# get interactions that fulfill the combined score and are not solently based on text mining...
		interactions = StringProteinLink.where(stringdb1_id: stringids)
																		.where("combined_score >= #{combined_score}")
																		.where("neighborhood > 0 OR fusion > 0 OR cooccurence > 0 OR coexpression > 0 OR experiments > 0 OR `database` > 0")
																		.pluck(:stringdb2_id)
		gene_ids = StringProteinAliasName.where(stringdb_id: interactions)
																			.where(source: "Ensembl"). #['Ensembl', 'Ensembl_HGNC', 'Ensembl_HGNC_curated_gene', 'Ensembl_MGI', 'Ensembl_MGI_curated_gene'])
																			where("alias LIKE 'ENSG%' OR alias LIKE 'ENSMUSG%'")
																			.pluck(:alias).uniq
		gene_ids.map!{|g| "'#{g}'" }
		"#{Vep::Ensembl.colname("gene_id")} IN (#{gene_ids.join(",")}) OR #{Vep::Ensembl.colname("gene_symbol")} IN (#{genes.join(",")})"
	end
	
	def ppi900(value, opts)
		find_links(value, opts, 900)
	end
	
	def ppi700(value, opts)
		find_links(value, opts, 700)
	end
	
	def ppi400(value, opts)
		find_links(value, opts, 400)
	end
	
	def ppi150(value, opts)
		find_links(value, opts, 150)
	end
	
	def ppi900_panel(value, opts)
		gene_lists = GenericGeneList.find_all_by_id(value)
		genes = gene_lists.map{|gl| gl.items.map{|gli| gli.value["gene"]}}.flatten.uniq
		genes.map!{|g| "'#{g}'"}
		# "(genetic_elements.hgnc IN (#{genes.join(", ")})) OR (genetic_elements.ensembl_gene_id IN (#{genes.join(", ")}))"
		find_links(genes, opts, 900)
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