class VepFilterDomain < SimpleFilter
		create_filter_for QueryGeneFeature, :domain_id,
						name: :vep_domain_pfam, 
						label: "PFAM id (e.g. PF00089)",
						filter_method: lambda{|val| filter_domain("Pfam_domain", val) },
						checked: false,
						organism: [organisms(:human), organisms(:mouse)], 
						requires: {
							Vep::Ensembl => [:domains]
						},
						tool: VepAnnotation
		create_filter_for QueryGeneFeature, :domain_id,
						name: :vep_domain_hmmpanther, 
						label: "HMM Panther id (e.g. PTHR24255)",
						filter_method: lambda{|val| filter_domain("hmmpanther", val) },
						checked: false,
						organism: [organisms(:human), organisms(:mouse)], 
						requires: {
							Vep::Ensembl => [:domains]
						},
						tool: VepAnnotation
		create_filter_for QueryGeneFeature, :domain_id,
						name: :vep_domain_superfamily, 
						label: "Super family domain id (e.g. SSF50494)",
						filter_method: lambda{|val| filter_domain("Superfamily_domains", val) },
						checked: false,
						organism: [organisms(:human), organisms(:mouse)], 
						requires: {
							Vep::Ensembl => [:domains]
						},
						tool: VepAnnotation
		create_filter_for QueryGeneFeature, :domain_id,
						name: :vep_domain_gene3d, 
						label: "Gene3d (e.g. 2)",
						filter_method: lambda{|val| filter_domain("Gene3d", val) },
						checked: false,
						organism: [organisms(:human), organisms(:mouse)], 
						requires: {
							Vep::Ensembl => [:domains]
						},
						tool: VepAnnotation
		create_filter_for QueryGeneFeature, :domain_id,
						name: :vep_domain_prosite, 
						label: "ProSite (e.g. PS50240)",
						filter_method: lambda{|val| filter_domain("PROSITE_profiles", val) },
						checked: false,
						organism: [organisms(:human), organisms(:mouse)], 
						requires: {
							Vep::Ensembl => [:domains]
						},
						tool: VepAnnotation
		create_filter_for QueryGeneFeature, :domain_id,
						name: :vep_domain_pirsf, 
						label: "PIRSF_domain (e.g. PIRSF001155)",
						filter_method: lambda{|val| filter_domain("PIRSF_domain", val) },
						checked: false,
						organism: [organisms(:human), organisms(:mouse)], 
						requires: {
							Vep::Ensembl => [:domains]
						},
						tool: VepAnnotation
		create_filter_for QueryGeneFeature, :domain_id,
						name: :vep_domain_smart, 
						label: "SMART domain (e.g. SM00020)",
						filter_method: lambda{|val| filter_domain("SMART_domains", val) },
						checked: false,
						organism: [organisms(:human), organisms(:mouse)], 
						requires: {
							Vep::Ensembl => [:domains]
						},
						tool: VepAnnotation
						
	create_filter_for QueryGeneFeature, :domain_panel,
						name: :vep_domain_pfam, 
						label: "PFAM id (e.g. PF00089)",
						filter_method: lambda{|val| filter_domain_panel("Pfam_domain", val) },
						collection_method: 	:list_panels,
						checked: true,
						organism: [organisms(:human), organisms(:mouse)], 
						requires: {
							Vep::Ensembl => [:domains]
						},
						tool: VepAnnotation
						
	create_filter_for QueryGeneFeature, :domain,
						name: :vep_domain, 
						label: "Affects domain",
						filter_method: lambda{|val| "#{Vep::Ensembl.colname(:domains)} IS NOT NULL" },
						checked: true,
						organism: [organisms(:human), organisms(:mouse)], 
						requires: {
							Vep::Ensembl => [:domains]
						},
						tool: VepAnnotation
	create_filter_for QueryGeneFeature, :domain,
						name: :vep_motif, 
						label: "Affects Motif",
						filter_method: lambda{|val| "#{Vep::Ensembl.colname(:motif_name)} IS NOT NULL" },
						checked: false,
						organism: [organisms(:human), organisms(:mouse)], 
						requires: {
							Vep::Ensembl => [:motif_name]
						},
						tool: VepAnnotation
	create_filter_for QueryGeneFeature, :domain,
						name: :vep_motif_high, 
						label: "Affects Motif (high impact)",
						filter_method: lambda{|val| "ABS(#{Vep::Ensembl.colname(:motif_score_change)}) > 0.1" },
						checked: true,
						organism: [organisms(:human), organisms(:mouse)], 
						requires: {
							Vep::Ensembl => [:motif_score_change]
						},
						tool: VepAnnotation
	create_filter_for QueryGeneFeature, :domain,
						name: :vep_motif_high_inf_pos, 
						label: "Affects important base in motif",
						filter_method: lambda{|val| "#{Vep::Ensembl.colname(:high_inf_pos)} = 1" },
						checked: false,
						organism: [organisms(:human), organisms(:mouse)], 
						requires: {
							Vep::Ensembl => [:high_inf_pos]
						},
						tool: VepAnnotation
						
	def filter_domain(name, id)
		id = id[1..-2] # remove surounding ''
		"#{Vep::Ensembl.colname(:domains)} RLIKE '.*#{name}:#{id}.*'"
	end
	
	def filter_domain_panel(name, panelids)
		gene_lists = GenericGeneList.find_all_by_id(panelids)
		domains = gene_lists.map{|gl| gl.items.map{|gli| (gli.value["domain"] || gli.value["gene"])}}.flatten.uniq
		return nil if domains.size == 0
		cond = domains.map{|d|".*#{name}:#{d}.*"}.uniq.join("|")
		"#{Vep::Ensembl.colname(:domains)} RLIKE ('#{cond}')"
	end
	
end