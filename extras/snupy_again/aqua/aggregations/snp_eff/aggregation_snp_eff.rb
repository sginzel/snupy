class AggregationSnpEffGeneids < Aggregation

	batch_attributes(SnpEff)

	register_aggregation :symbol,
												label: "Gene Symbol",
												colname: "Symbol (SNPEff)",
												colindex: 1.33,
												aggregation_method: :symbol,
												type: :attribute,
												checked: false,
												category: "SNPEff",
												record_color: {
													"Symbol (SNPEff)" => :factor_norm
												},
												requires: {
													SnpEff => [:symbol]
												}
	register_aggregation :ensembl_transcript,
												label: "Ensembl Transcript + Consequence",
												colname: "Transcript (SNPEff)",
												colindex: 4,
												aggregation_method: :enst,
												type: :attribute,
												category: "SNPEff",
												record_color: {
													"Transcript (SNPEff)" => {
														/.*chromosome.*/ => "salmon",
														/.*exon_loss_variant.*/ => "salmon",
														/.*frameshift_variant.*/ => "salmon",
														/.*rare_amino_acid_variant.*/ => "salmon",
														/.*splice_acceptor_variant.*/ => "salmon",
														/.*splice_donor_variant.*/ => "salmon",
														/.*stop_lost.*/ => "salmon",
														/.*start_lost.*/ => "salmon",
														/.*stop_gained.*/ => "salmon",
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
												},
												requires: {
													SnpEff => [:ensembl_feature_id, :annotation]
												}
	register_aggregation :ensembl_gene_id,
												label: "Ensembl Gene Id",
												colname: "Ensembl Gene Id (SNPEff)",
												colindex: 3.1,
												aggregation_method: "snp_effs.ensembl_gene_id",
												type: :attribute,
												category: "SNPEff",
												requires: {
													SnpEff => [:ensembl_gene_id]
												}
	register_aggregation :feature_type,
												label: "Ensembl Feature",
												colname: "Feature (SNPEff)",
												colindex: 4,
												aggregation_method: :ens_feature,
												type: :attribute,
												category: "SNPEff",
												record_color: {
													"Feature (SNPEff)" => {
														/^domain.*/ => "salmon",
														/transcript/ => "",
														/(beta_strand|helix)/ => "#ffff99",
														/topological_domain.*/ => "#ffff99",
														/.*/ => "lightyellow"
													}
												},
												requires: {
													SnpEff => [:ensembl_feature_type]
												}
	register_aggregation :hgvs,
												label: "HGVS",
												colname: "HGVS (SNPEff)",
												colindex: 4.1,
												aggregation_method: lambda{|rec| (!rec["hgvs_c"].nil?)?sprintf("DNA: %s, Protein: %s", rec["hgvs_c"].to_s, rec["hgvs_p"].to_s):""},
												type: :attribute,
												category: "SNPEff",
												requires: {
													SnpEff => [:hgvs_c, :hgvs_p]
												}
	register_aggregation :consequence,
												label: "Consequence",
												colname: "Consequence (SNPEff)",
												colindex: 1.65,
												aggregation_method: :consequence,
												type: :attribute,
												checked: true,
												category: "SNPEff",
												record_color: {
													"Consequence (SNPEff)" => {
														/.*chromosome.*/ => "salmon",
														/.*exon_loss_variant.*/ => "salmon",
														/.*frameshift_variant.*/ => "salmon",
														/.*rare_amino_acid_variant.*/ => "salmon",
														/.*splice_acceptor_variant.*/ => "salmon",
														/.*splice_donor_variant.*/ => "salmon",
														/.*stop_lost.*/ => "salmon",
														/.*start_lost.*/ => "salmon",
														/.*stop_gained.*/ => "salmon",
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
												},
												requires: {
													SnpEff => [:annotation]
												}
	register_aggregation :lof,
												label: "Loss-of-function",
												colname: "LOF (SNPEff)",
												colindex: 5.1,
												aggregation_method: lambda{|rec|
													{
														symbol: rec["snpeffs.lof_gene_name"],
														gene_id: rec["snpeffs.lof_gene_id"],
														num_transcripts: rec["snpeffs.lof_number_of_transcripts_in_gene"],
														percent_affected: rec["snpeffs.lof_percent_of_transcripts_affected"]
													}
												},
												color: {
													"LOF (SNPEff)[percent_affected]" => create_color_gradient([0,0.25, 0.75,1], colors = ["palegreen", "lightyellow", "lightsalmon", "salmon"]),
												},
												type: :attribute,
												category: "SNPEff",
												requires: {
													SnpEff => [:lof_gene_name, :lof_gene_id, :lof_number_of_transcripts_in_gene, :lof_percent_of_transcripts_affected]
												}
	register_aggregation :nmd,
												label: "Non-sense mediated decay",
												colname: "NMD (SNPEff)",
												colindex: 5.2,
												aggregation_method: lambda{|rec|
													{
														symbol: rec["snpeffs.nmd_gene_name"],
														gene_id: rec["snpeffs.nmd_gene_id"],
														num_transcripts: rec["snpeffs.nmd_number_of_transcripts_in_gene"],
														percent_affected: rec["snpeffs.nmd_percent_of_transcripts_affected"]
													}
												},
												color: {
													"NMD (SNPEff)[percent_affected]" => create_color_gradient([0,0.25, 0.75,1], colors = ["palegreen", "lightyellow", "lightsalmon", "salmon"]),
												},
												type: :attribute,
												category: "SNPEff",
												requires: {
													SnpEff => [:nmd_gene_name, :nmd_gene_id, :nmd_number_of_transcripts_in_gene, :nmd_percent_of_transcripts_affected]
												}
	def symbol(rec)
		linkout(
			label: "#{rec["snp_effs.symbol"]}",
			url:   "http://www.genecards.org/cgi-bin/carddisp.pl?gene=#{rec["snp_effs.symbol"]}"
		)
	end
	
	def enst(rec)
		linkout(
			label: "#{rec["snp_effs.ensembl_feature_id"]} (#{rec["snp_effs.annotation"]})",
			url:   "http://www.ensembl.org/Homo_sapiens/Transcript/Summary?t=#{rec["snp_effs.ensembl_feature_id"]}"
		)
	end

	def ens_feature(rec)
		"#{rec["snp_effs.ensembl_feature_type"]}"
	end

	def consequence(rec)
		rec["snp_effs.annotation"]
	end

end