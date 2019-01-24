class VepFilterGeneId < SimpleFilter
	# Gene ID
	create_filter_for QueryGeneId, :gene_id,
						name: :ensg_gene_id, 
						label: "Ensembl Gene ID",
						filter_method: lambda{|value| "#{Vep::Ensembl.colname(:gene_id)} IN (#{value.join(",")})"},
						organism: [organisms(:human), organisms(:mouse)],
						checked: false,
						requires: {
							Vep::Ensembl => [:gene_id]
						},
						tool: VepAnnotation
	create_filter_for QueryGeneId, :gene_id,
						name: :refseq_gene_id, 
						label: "RefSeq Gene ID",
						filter_method: lambda{|value| "#{Vep::RefSeq.colname(:gene_id)} IN (#{value.join(",")})"},
						organism: [organisms(:human), organisms(:mouse)], 
						checked: false, 
						requires: {
							Vep::RefSeq => [:gene_id]
						},
						tool: VepAnnotation
	
	# Transcript ID
	create_filter_for QueryGeneId, :gene_id,
						name: :ensg_transcript_id, 
						label: "Ensembl Transcript ID",
						filter_method: lambda{|value| "#{Vep::Ensembl.colname(:transcript_id)} IN (#{value.join(",")})"},
						organism: [organisms(:human), organisms(:mouse)], 
						checked: false,
						requires: {
							Vep::Ensembl => [:transcript_id]
						},
						tool: VepAnnotation
	create_filter_for QueryGeneId, :gene_id,
						name: :refseq_transcript_id, 
						label: "RefSeq Transcript ID",
						filter_method: lambda{|value| "#{Vep::RefSeq.colname(:transcript_id)} IN (#{value.join(",")})"},
						organism: [organisms(:human), organisms(:mouse)], 
						checked: false, 
						requires: {
							Vep::RefSeq => [:transcript_id]
						},
						tool: VepAnnotation
	
	# SYMBOL
	create_filter_for QueryGeneId, :gene_id,
						name: :vep_ens_symbol, 
						label: "Symbol Ensembl",
						filter_method: lambda{|value| "#{Vep::Ensembl.colname(:gene_symbol)} IN (#{value.join(",")})"},
						organism: [organisms(:human), organisms(:mouse)], 
						checked: true, 
						requires: { 
							Vep::Ensembl => [:gene_symbol]
						},
						tool: VepAnnotation
	create_filter_for QueryGeneId, :gene_id,
						name: :vep_refseq_symbol, 
						label: "Symbol RefSeq",
						filter_method: lambda{|value| "#{Vep::RefSeq.colname(:gene_symbol)} IN (#{value.join(",")})"},
						organism: [organisms(:human), organisms(:mouse)], 
						checked: false, 
						requires: { 
							Vep::RefSeq => [:gene_symbol]
						},
						tool: VepAnnotation
	
	# PANEL
	create_filter_for QueryGeneId, :gene_id_panel,
						name: :vep_ens_panel_symbol,
						label: "Ensembl Symbol",
						filter_method: lambda{|value| _panel(value, Vep::Ensembl.colname(:gene_symbol))},
						organism: [organisms(:human), organisms(:mouse)],
						checked: true, 
						collection_method: :list_panels,
						requires: {
							Vep::Ensembl => [:gene_symbol]
						},
						tool: VepAnnotation
	create_filter_for QueryGeneId, :gene_id_panel,
					  name: :vep_ens_panel_ensgene,
					  label: "Ensembl Gene",
					  filter_method: lambda{|value| _panel(value, Vep::Ensembl.colname(:gene_id))},
					  organism: [organisms(:human), organisms(:mouse)],
					  checked: false,
					  collection_method: :list_panels,
					  requires: {
						  Vep::Ensembl => [:gene_id]
					  },
					  tool: VepAnnotation
	create_filter_for QueryGeneId, :gene_id_panel,
					  name: :vep_ens_panel_enstranscript,
					  label: "Ensembl Transcript",
					  filter_method: lambda{|value| _panel(value, Vep::Ensembl.colname(:transcript_id))},
					  organism: [organisms(:human), organisms(:mouse)],
					  checked: false,
					  collection_method: :list_panels,
					  requires: {
						  Vep::Ensembl => [:transcript_id]
					  },
					  tool: VepAnnotation
	
	# PANEL RefSeq
	create_filter_for QueryGeneId, :gene_id_panel,
					  name: :vep_refseq_panel_symbol,
					  label: "RefSeq Symbol",
					  filter_method: lambda{|value| _panel(value, Vep::RefSeq.colname(:gene_symbol))},
					  organism: [organisms(:human), organisms(:mouse)],
					  checked: false,
					  collection_method: :list_panels,
					  requires: {
						  Vep::RefSeq => [:gene_symbol]
					  },
					  tool: VepAnnotation
	create_filter_for QueryGeneId, :gene_id_panel,
					  name: :vep_refseq_panel_ensgene,
					  label: "RefSeq Gene",
					  filter_method: lambda{|value| _panel(value, Vep::RefSeq.colname(:gene_id))},
					  organism: [organisms(:human), organisms(:mouse)],
					  checked: false,
					  collection_method: :list_panels,
					  requires: {
						  Vep::RefSeq => [:gene_id]
					  },
					  tool: VepAnnotation
	create_filter_for QueryGeneId, :gene_id_panel,
					  name: :vep_refseq_panel_enstranscript,
					  label: "RefSeq Transcript",
					  filter_method: lambda{|value| _panel(value, Vep::RefSeq.colname(:transcript_id))},
					  organism: [organisms(:human), organisms(:mouse)],
					  checked: false,
					  collection_method: :list_panels,
					  requires: {
						  Vep::RefSeq => [:transcript_id]
					  },
					  tool: VepAnnotation

						
#	create_filter_for QueryGeneId, :gene_id_panel,
#						name: :snpeff_symbol_list, 
#						label: "Symbol, Ensembl Gene Id",
#						filter_method: :snpeff_symbol_list,
#						collection_method: :list_panels,
#						organism: [organisms(:human), organisms(:mouse)], 
#						requires: {
#							SnpEff => [:symbol, :ensembl_gene_id]
#						},
#						tool: SnpEffAnnotation
#						
#	create_filter_for QueryGeneFeature, :domain,
#						name: :snp_eff_domain, 
#						label: "Sequence Feature",
#						filter_method: :domain,
#						checked: true,
#						organism: [organisms(:human), organisms(:mouse)], 
#						requires: {
#							SnpEff => [:annotation]
#						},
#						tool: SnpEffAnnotation
	
	def _panel(value, *columns)
		gene_lists = GenericGeneList.find_all_by_id(value)
		genes = gene_lists.map{|gl| gl.items.map{|gli| gli.value["gene"]}}.flatten.uniq
		genes.map!{|g| "'#{g}'"}
		ret = columns.map{|c| "(#{c} IN (#{genes.join(",")}))" }.join(" OR ")
		"(#{ret})"
	end

	

	
end