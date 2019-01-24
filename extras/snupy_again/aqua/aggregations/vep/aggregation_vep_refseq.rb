class AggregationRefSeq < Aggregation
	
	@@vepversion = VepAnnotation.config("ensembl_version")
	@@vepcategory = "VEP v#{@@vepversion} RefSeq"
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
	batch_attributes(Vep::RefSeq)

	register_aggregation :vep_refgene_gene,
											label: "RefSeq Gene",
											colname: "RefSeq Gene ID (VEP v#{@@vepversion})",
											colindex: 3.2,
											aggregation_method: lambda{|rec| 
												linkout(
												{label: rec[Vep::RefSeq.colname(:gene_id)], 
													url: "http://www.ncbi.nlm.nih.gov/gene/?term=#{rec[Vep::RefSeq.colname(:gene_id)]}"
												})
											},
											type: :attribute,
											checked: false,
											category: @@vepcategory,
											requires: {
												Vep::RefSeq => [:gene_id]
											}
											
	register_aggregation :vep_refgene_symbol,
											label: "RefSeq Symbol",
											colname: "RefSeq Symbol (VEP v#{@@vepversion})",
											colindex: 1.111 ,
											aggregation_method: lambda{|rec| 
												linkout(
												{label: rec[Vep::RefSeq.colname(:gene_symbol)], 
													url: "http://www.genecards.org/cgi-bin/carddisp.pl?gene=#{rec[Vep::RefSeq.colname(:gene_symbol)]}"
												})
											},
											type: :attribute,
											checked: false,
											category: @@vepcategory,
											record_color: {
												"RefSeq Symbol (VEP v#{@@vepversion})" => :factor_norm
											},
											requires: {
												Vep::RefSeq => [:gene_symbol]
											}
											
	register_aggregation :vep_consequence_refseq,
												label: "Transcript & Consequence RefSeq (VEP v#{@@vepversion})",
												colname: "Consequence (VEP RefSeq)",
												colindex: 5,
												checked: false,
												aggregation_method: lambda{|rec|
													lbl = "#{(rec[Vep::RefSeq.colname(:hgvsc)]||rec[Vep::RefSeq.colname(:transcript_id)])}#{(rec[Vep::RefSeq.colname(:canonical)].to_s=="1")?"*":""}(#{rec[Vep::RefSeq.colname(:consequence)]})"
													lbl << " DIST:#{rec[Vep::RefSeq.colname(:distance)]}" unless rec[Vep::RefSeq.colname(:distance)].nil? 
													linkout(
														label: lbl, 
														url: "http://www.ncbi.nlm.nih.gov/nuccore/#{rec[Vep::RefSeq.colname(:transcript_id)]}"
													) 
												},
												type: :attribute,
												category: @@vepcategory,
												record_color: {
													"Consequence (VEP RefSeq)" => @@color_consequence
												 },
												requires: {
													Vep::RefSeq => [:consequence, :hgvsc, :transcript_id, :distance, :canonical]
												}
												
	register_aggregation :vep_consequence_refseq_prot,
												label: "Protein & Consequence RefSeq (VEP v#{@@vepversion})",
												colname: "Protein (VEP RefSeq)",
												colindex: 5.1,
												checked: false,
												aggregation_method: lambda{|rec| 
													linkout(
														label: "#{(rec[Vep::RefSeq.colname(:hgvsp)]||rec[Vep::RefSeq.colname(:protein_id)])}#{(rec[Vep::RefSeq.colname(:canonical)].to_s=="1")?"*":""}(#{rec[Vep::RefSeq.colname(:consequence)]})", 
														url: "http://www.ncbi.nlm.nih.gov/protein/#{rec[Vep::RefSeq.colname(:protein_id)]}"
													) 
												},
												type: :attribute,
												category: @@vepcategory,
												record_color: {
													"Protein (VEP RefSeq)" => @@color_consequence
												 },
												requires: {
													Vep::RefSeq => [:consequence, :hgvsp, :protein_id, :canonical]
												}
												
	register_aggregation :vep_consequence_refseq_aa,
												label: "Amino Acid Exchange RefSeq (VEP v#{@@vepversion})",
												colname: "Amino Acid (VEP RefSeq)",
												colindex: 5.2,
												checked: false,
												aggregation_method: lambda{|rec| 
													rec[Vep::RefSeq.colname(:amino_acids)]
												},
												type: :attribute,
												category: @@vepcategory,
												requires: {
													Vep::RefSeq => [:amino_acids]
												}
												
	register_aggregation :vep_consequence_severe_refseq,
												label: "Most Severe Consequence RefSeq (VEP v#{@@vepversion})",
												colname: "Most Severe Consequence RefSeq",
												colindex: 1.61,
												checked: true,
												aggregation_method: lambda{|rec| "#{rec[Vep::RefSeq.colname(:most_severe_consequence)]}"},
												type: :attribute,
												category: @@vepcategory,
												record_color: {
													"Most Severe Consequence RefSeq" => @@color_consequence
												 },
												requires: {
													Vep::RefSeq => [:most_severe_consequence]
												}
												
	register_aggregation :vep_bp_overlap,
												label: "BP Overlap RefSeq (VEP v#{@@vepversion})",
												colname: "BP Overlap RefSeq VEP",
												colindex: 10,
												checked: false,
												aggregation_method: lambda{|rec|
													"#{rec[Vep::RefSeq.colname(:bp_overlap)]} (#{rec[Vep::RefSeq.colname(:gene_symbol)]})" 
												},
												type: :attribute,
												category: @@vepcategory,
												requires: {
													Vep::RefSeq => [:gene_symbol, :bp_overlap]
												}
		register_aggregation :vep_percentage_overlap,
												label: "Percentage Overlap RefSeq (VEP v#{@@vepversion})",
												colname: "Percentage Overlap RefSeq VEP",
												colindex: 10,
												checked: false,
												aggregation_method: lambda{|rec|
													"#{rec[Vep::RefSeq.colname(:percentage_overlap)]} (#{rec[Vep::RefSeq.colname(:gene_symbol)]})" 
												},
												type: :attribute,
												category: @@vepcategory,
												requires: {
													Vep::RefSeq => [:gene_symbol, :percentage_overlap]
												},
												record_color: {
													"Percentage Overlap RefSeq VEP" => create_color_gradient([0, 50, 100], colors = ["palegreen", "lightyellow", "salmon"])
												}
end