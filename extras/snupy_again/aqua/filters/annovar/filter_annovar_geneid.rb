class FilterAnnovarGeneid < SimpleFilter
	create_filter_for QueryGeneId, :gene_id,
						name: :annovar_gene,
						label: "Ensembl Gene/Transcript ID",
						filter_method: :gene_id_filter,
						organism: [organisms(:human), organisms(:mouse)],
						checked: false,
						requires: {
							Annovar => [:ensembl_gene, :ensembl_effect_transcript]
						},
						tool: AnnovarAnnotation
	create_filter_for QueryGeneId, :gene_id,
						name: :annovar_ensg_symbol,
						label: "Ensembl Gene Symbol",
						filter_method: :alias_filter,
						organism: [organisms(:human), organisms(:mouse)],
						checked: false,
						requires: {
							Annovar => {AnnovarAlias => [:alias]}
						},
						tool: AnnovarAnnotation
	create_filter_for QueryGeneId, :gene_id,
						name: :annovar_refgene,
						label: "RefSeq Gene Transcript",
						filter_method: :gene_id_filter,
						organism: [organisms(:human), organisms(:mouse)],
						checked: false,
						requires: {
							Annovar => [:refgene_gene, :refgene_effect_transcript]
						},
						tool: AnnovarAnnotation
	create_filter_for QueryGeneId, :gene_id,
						name: :annovar_flanking_ensembl,
						label: "Ensembl Gene/Transcript (flanking)",
						filter_method: :gene_id_filter,
						organism: [organisms(:human), organisms(:mouse)],
						checked: false,
						requires: {
							Annovar => [:ensembl_right_gene_neighbor, :ensembl_left_gene_neighbor]
						},
						tool: AnnovarAnnotation
		create_filter_for QueryGeneId, :gene_id,
						name: :annovar_flanking_refgene,
						label: "RefSeq Gene/Transcript (flanking)",
						filter_method: :gene_id_filter,
						organism: [organisms(:human), organisms(:mouse)],
						checked: false,
						requires: {
							Annovar => [:refgene_right_gene_neighbor, :refgene_left_gene_neighbor]
						},
						tool: AnnovarAnnotation
	
		create_filter_for QueryGeneId, :gene_id_panel,
						name: :annovar_ensembl_panel_ensgeneid,
						label: "Ensembl Gene ID",
						filter_method: :gene_id_panel_filter,
						collection_method: :list_panels,
						checked: false,
						organism: [organisms(:human), organisms(:mouse)],
						requires: {
							Annovar => [:ensembl_gene]
						},
						tool: AnnovarAnnotation
		create_filter_for QueryGeneId, :gene_id_panel,
					  name: :annovar_ensembl_panel_enstransid,
					  label: "Ensembl Transcript ID",
					  filter_method: :gene_id_panel_filter,
					  collection_method: :list_panels,
					  checked: false,
					  organism: [organisms(:human), organisms(:mouse)],
					  requires: {
						  Annovar => [:ensembl_effect_transcript]
					  },
					  tool: AnnovarAnnotation
		create_filter_for QueryGeneId, :gene_id_panel,
						name: :annovar_refgene_panel_geneid,
						label: "RefSeq Gene Symbol",
						filter_method: :gene_id_panel_filter,
						collection_method: :list_panels,
						checked: false,
						organism: [organisms(:human), organisms(:mouse)],
						requires: {
							Annovar => [:refgene_gene]
						},
						tool: AnnovarAnnotation
		create_filter_for QueryGeneId, :gene_id_panel,
					  name: :annovar_refgene_panel_transid,
					  label: "RefSeq Transcript",
					  filter_method: :gene_id_panel_filter,
					  collection_method: :list_panels,
					  checked: false,
					  organism: [organisms(:human), organisms(:mouse)],
					  requires: {
						  Annovar => [:refgene_effect_transcript]
					  },
					  tool: AnnovarAnnotation
		# Micro RNAs
		create_filter_for QueryGeneFeature, :mirna_target,
						name: :annovar_is_micro_rna,
						label: "microRNA affected by variant",
						filter_method: lambda{|rec| "annovars.refgene_gene LIKE 'mir%'"},
						organism: [organisms(:human)],
						checked: true,
						requires: {
							Annovar => [:refgene_gene]
						},
						tool: AnnovarAnnotation
		create_filter_for QueryGeneFeature, :mirna_target,
						name: :annovar_is_mirna_target,
						label: "miRNA target site affected by variant",
						filter_method: lambda{|rec| "annovars.micro_rna_target_name IS NOT NULL"},
						organism: [organisms(:human)],
						checked: false,
						requires: {
							Annovar => [:micro_rna_target_name]
						},
						tool: AnnovarAnnotation
		create_filter_for QueryGeneFeature, :mirna_target,
						name: :annovar_is_mirna_target_hc,
						label: "miRNA target site affected by variant (high confidence - score > 85)",
						filter_method: lambda{|rec| "annovars.micro_rna_target_name IS NOT NULL AND annovars.micro_rna_target_score > 85"},
						organism: [organisms(:human)],
						requires: {
							Annovar => [:micro_rna_target_name, :micro_rna_target_score]
						},
						tool: AnnovarAnnotation
	create_filter_for QueryGeneFeature, :motif,
										name: :annovar_motif_affected,
										label: "Affects TFBS motif (AnnoVar)",
										filter_method: lambda{|rec| "annovars.tfbs_motif_name IS NOT NULL"},
										organism: [organisms(:human)],
										checked: true,
										requires: {
												Annovar => [:tfbs_motif_name]
										},
										tool: AnnovarAnnotation
	create_filter_for QueryGeneFeature, :motif,
										name: :annovar_motif_affected,
										label: "Affects TFBS motif (AnnoVar) (score > 750)",
										filter_method: lambda{|rec| "annovars.tfbs_score >= 750"},
										organism: [organisms(:human)],
										checked: false,
										requires: {
												Annovar => [:tfbs_score]
										},
										tool: AnnovarAnnotation
	def gene_id_filter(value, params)
		organism_id = params["experiment"].organism.id
		columns = self.requirements[Annovar]
		columns.map{|colname|
			"(annovars.#{colname} IN (#{value.join(",")}) AND annovars.organism_id = #{organism_id})"
		}.join(" OR ")
	end
	
	def gene_id_panel_filter(value, params)
		gene_lists = GenericGeneList.find_all_by_id(value)
		genes = gene_lists.map{|gl| gl.items.map{|gli| gli.value["gene"]}}.flatten.uniq
		genes.map!{|g| "'#{g}'"}
		gene_id_filter(genes, params)
	end
	
	def alias_filter(value, params)
		organism_id = params["experiment"].organism.id
		"(annovar_ensembl2alias.alias IN (#{value.join(", ")}) AND annovar_ensembl2alias.organism_id = annovars.organism_id AND annovars.organism_id = #{organism_id})"
	end
	
	def self.list_panels(params)
		#User.find(params[:user]).generic_gene_lists.map{|ggl|
		current_user.find(params[:user]).generic_gene_lists.map{|ggl|
			{
				id: ggl.id,
				name: ggl.name,
				title: ggl.title,
				description: ggl.description
			}
		}
	end
	
end