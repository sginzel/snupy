class AggregationVep < Aggregation
	
	@@vepversion = VepAnnotation.config("ensembl_version")
	@@vepcategory = "VEP v#{@@vepversion}"
	@@color_consequence = {
														/.*chromosome.*/ => "salmon",
														/.*exon_loss_variant.*/ => "salmon",
														/.*frameshift_variant.*/ => "salmon",
														/.*rare_amino_acid_variant.*/ => "salmon",
														/.*splice_acceptor_variant.*/ => "salmon",
														/.*splice_donor_variant.*/ => "salmon",
														/.*stop_lost.*/ => "salmon",
														/.*start_lost.*/ => "salmon",
														/.*stop_gained.*/ => "salmon",
														/.*mature_miRNA_variant.*/ => "salmon",
														/.*TF_binding_site_variant.*/ => "#ffff99",
														/.*coding_sequence_variant.*/ => "#ffff99",
														/.*inframe_insertion.*/ => "#ffff99",
														/.*disruptive_inframe_insertion.*/ => "#ffff99",
														/.*inframe_deletion.*/ => "#ffff99",
														/.*disruptive_inframe_deletion.*/ => "#ffff99",
														/.*missense_variant.*/ => "#ffff99",
														/.*splice_region_variant.*/ => "#ffff99",
														/.*3_prime_UTR_truncation.*/ => "#ffff99",
														/.*5_prime_UTR_truncation.*/ => "#ffff99"
													}
	@@color_aa_class = {
														/.*small.*/ => "#8dd3c7",
														/.*tiny.*/ => "#b3de69",
														/.*aromatic.*/ => "#ffffb3",
														/.*hydrophobic.*/ => "#80b1d3",
														/.*polar.*/ => "#fdb462",
														/.*aliphatic.*/ => "#ccebc5",
														/.*charged.*/ => "#fb8072",
														/.*positive.*/ => "#fccde5",
														/.*negative.*/ => "#bc80bd",
														/.*proline.*/ => "#bebada",
											}
	batch_attributes(Vep::Ensembl)
	
	# TODO: Links to Ensembl should link to Mus Musculus or Homo Sapiens depending on organism. 
	# TODO: Make organism available for aggregations?
	register_aggregation :vep_dbsnp,
												label: "dbSNP",
												colname: "dbSNP (VEP)",
												colindex: 2,
												aggregation_method: lambda{|rec|
													dbsnpalleles = rec[Vep::Ensembl.colname(:dbsnp_allele)].to_s.split(",")
													rec[Vep::Ensembl.colname(:dbsnp)].to_s.split(",").each_with_index.map{|dbsnp, i|
														"#{dbsnp} (#{dbsnpalleles[i]})"
													}
												},
												type: :attribute,
												checked: true,
												category: @@vepcategory,
												requires: {
													Vep::Ensembl => [:dbsnp, :dbsnp_allele]
												}
												
	register_aggregation :vep_ensembl_gene_id,
												label: "Ensembl Gene Id",
												colname: "Ensembl Gene Id (VEP v#{@@vepversion})",
												colindex: 3.1,
												aggregation_method: lambda{|rec| 
													linkout(
														label: rec[Vep::Ensembl.colname(:gene_id)], 
														url: "http://#{VepAnnotation.config("ensmirror")}/Homo_sapiens/Gene/Summary?g=#{rec[Vep::Ensembl.colname(:gene_id)]}"
													)
												},
												type: :attribute,
												record_color: {
													"Ensembl Gene Id (VEP v#{@@vepversion})" => :factor_norm
												},
												checked: false,
												category: @@vepcategory,
												requires: {
													Vep::Ensembl => [:gene_id]
												}
	

	## Symbol
	register_aggregation :vep_ensembl_symbol,
												label: "Ensembl Symbol",
												colname: "Ensembl Symbol (VEP v#{@@vepversion})",
												colindex: 1.11,
											 	prehook: :gene_symbol_biotype_prehook,
												aggregation_method: lambda{|rec|
													gene_symbol = rec[Vep::Ensembl.colname(:gene_symbol)].to_s.gsub(/\(.*\)$/, "")
													linkout(
														label: rec[Vep::Ensembl.colname(:gene_symbol)],
														url: {
															"GeneCards" => "http://www.genecards.org/cgi-bin/carddisp.pl?gene=#{gene_symbol}",
															"GHR" => "https://ghr.nlm.nih.gov/gene/#{gene_symbol}"
														}
													)
												},
												type: :attribute,
												checked: true,
												category: @@vepcategory,
												record_color: {
													"Ensembl Symbol (VEP v#{@@vepversion})" => Proc.new{ |record_text|
														if (record_text.index("pseudogene")) then
															"white"
														elsif (record_text.index("lincRNA")) then
															"white"
														elsif (record_text.index(/\(IG.*/)) then
															"white"
														elsif (record_text.index("miRNA")) then
															"palegreen"
														elsif (record_text.index("snoRNA")) then
															"palegreen"
														elsif (record_text.index("tf_binding_site")) then
															"palegreen"
														else
															Aqua.factor_color(record_text.to_s.strip.downcase)
														end
													}
												},
												requires: {
													Vep::Ensembl => [:gene_symbol, :biotype]
												}
	
	
	## CONSEQEUCENS & Transcript
	register_aggregation :vep_consequence_ensembl,
												label: "Transcript & Consequence Ensembl (VEP v#{@@vepversion})",
												colname: "Consequence (VEP Ensembl)",
												colindex: 5,
												checked: true,
												aggregation_method: lambda{|rec|
													if (rec[Vep::Ensembl.colname(:hgvsc)].nil?) then
														lbl = "#{(rec[Vep::Ensembl.colname(:transcript_id)])}#{(rec[Vep::Ensembl.colname(:canonical)].to_s=="1")?"*":""}(#{rec[Vep::Ensembl.colname(:consequence)]})"
													else
														lbl = "#{rec[Vep::Ensembl.colname(:transcript_id)]}.#{(rec[Vep::Ensembl.colname(:hgvsc)])}#{(rec[Vep::Ensembl.colname(:canonical)].to_s=="1")?"*":""}(#{rec[Vep::Ensembl.colname(:consequence)]})"
													end
													lbl << " DIST:#{rec[Vep::Ensembl.colname(:distance)]}" unless rec[Vep::Ensembl.colname(:distance)].nil?
													linkout(
														label: lbl, 
														url: "http://#{VepAnnotation.config("ensmirror")}/Homo_sapiens/Gene/Summary?t=#{rec[Vep::Ensembl.colname(:transcript_id)]}"
													) 
												},
												type: :attribute,
												category: @@vepcategory,
												record_color: {
													"Consequence (VEP Ensembl)" => @@color_consequence
												 },
												requires: {
													Vep::Ensembl => [:consequence, :hgvsc, :transcript_id, :distance, :canonical]
												}

	## CONSEQEUCENS & Protein
	register_aggregation :vep_consequence_ensembl_prot,
												label: "Protein & Consequence Ensembl (VEP v#{@@vepversion})",
												colname: "Protein (VEP Ensembl)",
												colindex: 5.1,
												checked: false,
												aggregation_method: lambda{|rec|
													if !rec[Vep::Ensembl.colname(:hgvsp)].nil? then
														prot = "#{rec[Vep::Ensembl.colname(:protein_id)]}.#{rec[Vep::Ensembl.colname(:hgvsp)]}"
													else
														prot = rec[Vep::Ensembl.colname(:protein_id)].to_s
													end
													prot << "*" if rec[Vep::Ensembl.colname(:canonical)].to_s=="1"
													linkout(
														label: "#{prot}(#{rec[Vep::Ensembl.colname(:consequence)]})", 
														url: "http://#{VepAnnotation.config("ensmirror")}/Homo_sapiens/Transcript/ProteinSummary?p=#{rec[Vep::Ensembl.colname(:protein_id)]}"
													) 
												},
												type: :attribute,
												category: @@vepcategory,
												record_color: {
													"Protein (VEP Ensembl)" => @@color_consequence
												 },
												requires: {
													Vep::Ensembl => [:consequence, :hgvsp, :protein_id, :canonical]
												}

	register_aggregation :vep_consequence_vep_aa_class,
												label: "Amino Acid Class Change Ensembl (VEP v#{@@vepversion})",
												colname: "Amino Acid Class Change (VEP Ensembl)",
												colindex: 5.3,
												checked: true,
												aggregation_method: lambda{|rec|
													ret = {"From" => [], "To" => []} 
													return ret if rec[Vep::Ensembl.colname(:amino_acids)].nil?
													[rec[Vep::Ensembl.colname(:amino_acids)].to_s.split("/")].each{|aafrom, aato|
														ret["From"] = Vep.AA_GROUPS_REVERSE[aafrom]
														ret["To"] = Vep.AA_GROUPS_REVERSE[aato]
													}
													ret
												},
												type: :attribute,
												category: @@vepcategory,
												record_color: {
													"Amino Acid Class Change (VEP Ensembl)[From]" => @@color_aa_class,
													"Amino Acid Class Change (VEP Ensembl)[To]" => @@color_aa_class
												 },
												requires: {
													Vep::Ensembl => [:amino_acids]
												}
	register_aggregation :vep_consequence_vep_aa,
												label: "Amino Acid Exchange Ensembl (VEP v#{@@vepversion})",
												colname: "Amino Acid (VEP Ensembl)",
												colindex: 5.2,
												checked: false,
												aggregation_method: lambda{|rec| 
													rec[Vep::Ensembl.colname(:amino_acids)]
												},
												type: :attribute,
												category: @@vepcategory,
												requires: {
													Vep::Ensembl => [:amino_acids]
												}

												
	register_aggregation :vep_consequence_severe_ensembl,
												label: "Most Severe Consequence (VEP v#{@@vepversion})",
												colname: "Most Severe Consequence Ensembl",
												colindex: 1.6,
												checked: true,
												aggregation_method: lambda{|rec| "#{rec[Vep::Ensembl.colname(:most_severe_consequence)]}"},
												type: :attribute,
												category: @@vepcategory,
												record_color: {
													"Most Severe Consequence Ensembl" => @@color_consequence
												 },
												requires: {
													Vep::Ensembl => [:most_severe_consequence]
												}

												
	register_aggregation :vep_tfbs,
												label: "Transcription Factor Binding Site",
												colname: "TFBS (VEP)",
												colindex: 6,
												checked: false,
												aggregation_method: lambda{|rec|
													return "" if rec[Vep::Ensembl.colname(:motif_name)].nil?
													linkout({
														label: "#{rec[Vep::Ensembl.colname(:motif_name)]}(#{Vep::Ensembl.colname(:motif_pos)})[HIGH?#{Vep::Ensembl.colname(:high_inf_pos)?"YES":"NO"}]", 
														url: "http://www.broadinstitute.org/gsea/msigdb/cards/#{rec[Vep::Ensembl.colname(:motif_name)]}"
													})
												},
												type: :attribute,
												category: @@vepcategory,
												color: {
													"TFBS (VEP)" => { /.*HIGH\?YES.*/ => "salmon" }
												},
												requires: {
													Vep::Ensembl => [:motif_feature_id, :motif_name, :high_inf_pos]
												}
	register_aggregation :vep_tfbs_score,
												label: "TFBS Binding Change",
												colname: "TFBS Binding Score Change (VEP)",
												colindex: 6.1,
												checked: false,
												aggregation_method: lambda{|rec|
													rec[Vep::Ensembl.colname(:motif_score_change)]
												},
												type: :attribute,
												category: @@vepcategory,
												color: {
													"TFBS Binding Score Change (VEP)" => create_color_gradient([-0.2, 0, 0.2], colors = ["salmon", "white", "palegreen"])
												},
												requires: {
													Vep::Ensembl => [:motif_score_change]
												}
												
	# POPULATION
	register_aggregation :vep_popfreq_vep,
												label: "Population Frequency",
												colname: "Pop. Freq. (VEP)",
												colindex: 7,
												aggregation_method: :aggregate_requirements,
												type: :attribute,
												checked: true,
												category: @@vepcategory,
												color: {
													/Pop. Freq. \(VEP\).*/ => create_color_gradient([0, 0.15, 1], colors = ["salmon", "lightyellow", "palegreen"])
												},
												requires: {
													Vep::Ensembl => [:minor_allele_freq, :exac_adj_maf]
												}
												
	register_aggregation :vep_lofp,
												label: "Loss Of Function Predictions (Ensembl)",
												colname: "LoFP(VEP)",
												colindex: 8,
												aggregation_method: :aggregate_requirements,
												type: :attribute,
												checked: true,
												category: @@vepcategory,
												color: {
													"LoFP(VEP)[polyphen_prediction]" => {"possibly_damaging" => "salmon", "probably_damaging" => "lightsalmon", "unknown" => "lightyellow", "benign" => "palegreen"},
													"LoFP(VEP)[sift_prediction]" => {"deleterious" => "salmon", "deleterious_low_confidence" => "lightsalmon", "tolerated_low_confidence" => "lightyellow", "tolerated" => "palegreen"}
												},
												requires: {
													Vep::Ensembl => [:polyphen_prediction, :sift_prediction]
												}
	
	register_aggregation :vep_clinical,
												label: "Clinical significance",
												colname: "Clin. Sign. (VEP)",
												colindex: 9,
												aggregation_method: :aggregate_requirements,
												type: :attribute,
												checked: false,
												category: @@vepcategory,
												record_color: {
													/Clin. Sign. \(VEP\).*/ => {"1" => "salmon", "0" => "palegreen", 1=>"salmon", 0=>"palegreen", true=>"salmon", false=>"palegreen"}
												},
												requires: {
													Vep::Ensembl => [:somatic, :gene_pheno, :phenotype_or_disease, :clin_sig]
												}
												
	register_aggregation :vep_pubmed,
												label: "PubMed",
												colname: "Pubmed (VEP v#{@@vepversion})",
												colindex: 9.1,
												aggregation_method: lambda{|rec| 
													return "" if rec[Vep::Ensembl.colname(:pubmed)].nil?
													rec[Vep::Ensembl.colname(:pubmed)].to_s.split(",").map{|pid|
														linkout({label: 
															pid, 
															url: "http://http://www.ncbi.nlm.nih.gov/pubmed/#{pid}"}
														)
													}.join(", ")
												},
												type: :attribute,
												checked: false,
												category: @@vepcategory,
												requires: {
													Vep::Ensembl => [:pubmed]
												}
												
	register_aggregation :vep_ext_protids,
												label: "External Protein ids (VEP v#{@@vepversion})",
												colname: "external VEP",
												colindex: 20,
												checked: false,
												aggregation_method: :aggregate_requirements,
												type: :attribute,
												category: @@vepcategory,
												requires: {
													Vep::Ensembl => [:trembl_id, :uniparc, :swissprot]
												}
	register_aggregation :vep_domains,
												label: "Domain Identifier (VEP v#{@@vepversion})",
												colname: "domainID VEP",
												colindex: 20,
												checked: false,
												aggregation_method: :aggregate_requirements,
												type: :attribute,
												category: @@vepcategory,
												record_color: {
													"Domain Identifier (VEP v#{@@vepversion})" => :factor_norm
												},
												requires: {
													Vep::Ensembl => [:domains]
												}
												
	register_aggregation :vep_ccds,
												label: "CCDS (VEP v#{@@vepversion})",
												colname: "CCDS VEP",
												colindex: 10,
												checked: false,
												aggregation_method: lambda{|rec|
													"#{rec[Vep::Ensembl.colname(:ccds)]}" 
												},
												type: :attribute,
												category: @@vepcategory,
												requires: {
													Vep::Ensembl => [:ccds]
												}
	
	register_aggregation :vep_bp_overlap,
												label: "BP Overlap (VEP v#{@@vepversion})",
												colname: "BP Overlap VEP",
												colindex: 10,
												checked: false,
												aggregation_method: lambda{|rec|
													"#{rec[Vep::Ensembl.colname(:bp_overlap)]} (#{rec[Vep::Ensembl.colname(:gene_symbol)]})" 
												},
												type: :attribute,
												category: @@vepcategory,
												requires: {
													Vep::Ensembl => [:gene_symbol, :bp_overlap]
												}
		register_aggregation :vep_percentage_overlap,
												label: "Percentage Overlap (VEP v#{@@vepversion})",
												colname: "Percentage Overlap VEP",
												colindex: 10,
												checked: false,
												aggregation_method: lambda{|rec|
													"#{rec[Vep::Ensembl.colname(:percentage_overlap)]} (#{rec[Vep::Ensembl.colname(:gene_symbol)]})" 
												},
												type: :attribute,
												category: @@vepcategory,
												requires: {
													Vep::Ensembl => [:gene_symbol, :percentage_overlap]
												},
												record_color: {
													"Percentage Overlap VEP" => create_color_gradient([0, 50, 100], colors = ["palegreen", "lightyellow", "salmon"])
												}

	register_aggregation :vep_gene_panel,
											 label: "Gene Panels",
											 colname: "VEP panels",
											 colindex: 1.1,
											 checked: true,
											 prehook: :get_panel_genes,
											 aggregation_method: :add_panels,
											 type: :attribute,
											 category: @@vepcategory,
											 requires: {
													 Vep::Ensembl => [:gene_symbol, :gene_id]
											 },
											 record_color: {
													 "VEP panels[names]" => :factor_norm,
													 "VEP panels[num_panels]" => create_color_gradient([0, 5, 10], colors = ["palegreen", "lightyellow", "salmon"])
											 }
	

	def get_panel_genes(rows, params)
		if params[:user].nil? then
			@panels = [["", []]]
			return
		end
		usr = User.find(params[:user])
		@panels = usr.visible(GenericGeneList).map do |ggl|
			pnlname = ggl.name
			pnlname = ggl.title if pnlname.to_s == ""
			pnlname = ggl.id if pnlname.to_s == ""
			[pnlname, ggl.genes]
		end
	end

	def add_panels(rec)
		symbol = rec[Vep::Ensembl.colname(:gene_symbol)]
		pnls_hit = @panels.select do |name, genes|
			genes.include?(rec[Vep::Ensembl.colname(:gene_symbol)]) ||
			genes.include?(rec[Vep::Ensembl.colname(:gene_id)])
		end
		rec["VEP panels"] = {
				names: pnls_hit.map{|name, genes| "#{name}(#{genes.size} genes)"},
				num_panels: (pnls_hit.size>0)?("#{pnls_hit.size} (#{symbol})"):""
		}
	end

	# this prehook marks some genes with their biotype, if it is an interesting one.
	# These are later maked special in color
	def gene_symbol_biotype_prehook(tbl)
		of_interest = %w(pseudogene lincRNA snoRNA miRNA tf_binding_site) + [/^IG/]

		tbl.each do |vcid, recs|
			recs.each do |rec|
				btpe = rec[Vep::Ensembl.colname(:biotype)].to_s
				if of_interest.any?{|pattern| btpe.index(pattern)} then
					rec[Vep::Ensembl.colname(:gene_symbol)] = "#{rec[Vep::Ensembl.colname('gene_symbol')]}(#{btpe})"
				end
			end
		end
	end

	def aggregate_requirements(rec, params, klass = Vep::Ensembl)
		ret = {}
		popcols = [:minor_allele_freq, :exac_adj_maf]
		self.requirements[klass].each do |colname|
			ret[colname] = rec[klass.colname(colname)]
			if popcols.include?(colname) then
				ret[colname] = 0 if ret[colname].to_s == ""
			end
		end
		ret
	end
	

	
end