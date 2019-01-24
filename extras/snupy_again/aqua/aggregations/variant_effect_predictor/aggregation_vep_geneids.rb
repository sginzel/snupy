class AggregationVepGeneids < Aggregation
	register_aggregation :symbol,
												label: "Gene Symbol",
												colname: "Symbol (VEP)",
												colindex: 3,
												aggregation_method: :hgnc,
												type: :attribute,
												checked: false,
												category: "Variant Effect Predictor",
												requires: {
													VariationAnnotation => {
														GeneticElement => [:hgnc]
													}
												},
												active: false
	register_aggregation :ensembl_gene_id,
												label: "Ensembl Gene Id",
												colname: "Ensembl Gene Id (VEP)",
												colindex: 3.1,
												aggregation_method: "genetic_elements.ensembl_gene_id",
												type: :attribute,
												checked: false,
												category: "Variant Effect Predictor",
												requires: {
													VariationAnnotation => {
														GeneticElement => [:ensembl_gene_id]
													}
												},
												active: false
register_aggregation :rsid,
												label: "dbSNP",
												colname: "dbSNP (VEP)",
												colindex: 3.2,
												aggregation_method: lambda{|rec| 
													ret = YAML.load(rec["variation_annotations.existing_variation"].to_s)
													if ret then
														ret = [ret] unless ret.is_a?(Array)
														ret = ret.map{|x| 
															linkout(
																label: x,
																url:   "http://www.ensembl.org/Homo_sapiens/Variation/Explore?v=#{x}" # does not work for other organisms yet...
															)
														}
													else
														ret = ""
													end
													ret
												},
												type: :attribute,
												checked: false,
												category: "Variant Effect Predictor",
												record_color: {
													"dbSNP (VEP)" => {
														/.*COSM.*/ => "salmon"
													}
												},
												requires: {
													VariationAnnotation => [:existing_variation]
												},
												active: false
	register_aggregation :ensembl_transcript,
												label: "Ensembl Transcript + Consequence",
												colname: "Transcript (VEP)",
												colindex: 4,
												aggregation_method: :enst,
												type: :attribute,
												category: "Variant Effect Predictor",
												record_color: {
													"Transcript (VEP)" => {
														/.*transcript_ablation.*/ => "salmon",
														/.*splice_acceptor_variant.*/ => "salmon",
														/.*splice_donor_variant.*/ => "salmon",
														/.*stop_gained.*/ => "salmon",
														/.*frameshift_variant.*/ => "salmon",
														/.*stop_lost.*/ => "salmon",
														/.*initiator_codon_variant.*/ => "salmon",
														/.*transcript_amplification.*/ => "#ffff99",
														/.*inframe_insertion.*/ => "#ffff99",
														/.*inframe_deletion.*/ => "#ffff99",
														/.*missense_variant.*/ => "#ffff99",
														/.*splice_region_variant.*/ => "#ffff99",
														/.*mature_miRNA_variant.*/ => "#ffff99",
														/.*TF_binding_site_variant.*/ => "#ffff99"
													}
												},
												requires: {
													VariationAnnotation => {
														GeneticElement => [:ensembl_feature_id],
														Consequence => [:consequence]
													}
												},
												active: false
	register_aggregation :consequence,
												label: "Consequence (VEP)",
												colname: "Consequence (VEP)",
												colindex: 5,
												aggregation_method: :consequence,
												type: :attribute,
												checked: false,
												category: "Variant Effect Predictor",
												record_color: {
													"Consequence (VEP)" => {
														/.*transcript_ablation.*/ => "salmon",
														/.*splice_acceptor_variant.*/ => "salmon",
														/.*splice_donor_variant.*/ => "salmon",
														/.*stop_gained.*/ => "salmon",
														/.*frameshift_variant.*/ => "salmon",
														/.*stop_lost.*/ => "salmon",
														/.*initiator_codon_variant.*/ => "#ffff99",
														/.*transcript_amplification.*/ => "#ffff99",
														/.*inframe_insertion.*/ => "#ffff99",
														/.*inframe_deletion.*/ => "#ffff99",
														/.*missense_variant.*/ => "#ffff99",
														/.*splice_region_variant.*/ => "#ffff99",
														/.*mature_miRNA_variant.*/ => "#ffff99",
														/.*TF_binding_site_variant.*/ => "#ffff99"
													}
												},
												requires: {
													VariationAnnotation => {
														Consequence => [:consequence]
													}
												},
												active: false
	register_aggregation :lof,
												label: "Loss of Function",
												colname: "LoF",
												colindex: 10,
												aggregation_method: :lof,
												type: :attribute,
												category: "Variant Effect Predictor",
												record_color: {
													/LoF\[.*\]/ => {
														/probably_damaging.*/ => "salmon",
														/deleterious.*/ => "salmon",
														/possibly_damaging.*/ => "#ffff99"
													}
												},
												requires: {
													VariationAnnotation => {
														select: [:polyphen_score, :sift_score],
														LossOfFunction => [:polyphen, :sift]
													}
												},
												active: false
	register_aggregation :blosum,
												label: "BLOSUM62 score",
												colname: "BLOSUM62",
												colindex: 8.2,
												aggregation_method: lambda{|rec| rec["variation_annotations.blosum62"]},
												type: :attribute,
												category: "Variant Effect Predictor",
												color: {
													"BLOSUM62" => create_color_gradient([-20,-10, 0,10,20], colors = ["red", "salmon", "lightyellow", "palegreen", "limegreen"]),
												},
												requires: {
													VariationAnnotation => [:blosum62]
												},
												active: false
	register_aggregation :domains,
												label: "Domains",
												colname: "Domains (VEP)",
												colindex: 4.1,
												aggregation_method: lambda{|rec| 
													if not rec["variation_annotations.domains"].nil? then
														YAML.load(rec["variation_annotations.domains"]).uniq
													else
														nil
													end
												},
												type: :attribute,
												category: "Variant Effect Predictor",
												requires: {
													VariationAnnotation => [:domains]
												},
												active: false
	register_aggregation :motifs,
												label: "Motifs",
												colname: "Motifs (VEP)",
												colindex: 4.2,
												aggregation_method: lambda{|rec| 
													tmp, id = rec["variation_annotations.motif_name"].to_s.split(":")
													if !id.nil? then
														linkout(
															label: "JASPER:#{id} (#{rec["variation_annotations.motif_pos"]})",
															url:   "http://jaspar.genereg.net/cgi-bin/jaspar_db.pl?ID=#{id}&rm=present&collection=CORE"
														)
													end
												},
												type: :attribute,
												category: "Variant Effect Predictor",
												requires: {
													VariationAnnotation => [:motif_name, :motif_pos]
												},
												active: false

	def hgnc(rec)
		linkout(
			label: "#{rec["genetic_elements.hgnc"]}",
			url:   "http://www.genecards.org/cgi-bin/carddisp.pl?gene=#{rec["genetic_elements.hgnc"]}"
		)
	end

	def enst(rec)
		linkout(
			label: "#{rec["genetic_elements.ensembl_feature_id"]} (#{rec["consequences.consequence"]})",
			url:   "http://www.ensembl.org/Homo_sapiens/Transcript/Summary?t=#{rec["genetic_elements.ensembl_feature_id"]}"
		)
	end
	
	def consequence(rec)
		rec["consequences.consequence"]
	end
	
	def lof(rec)
		{
			"Polyphen" => (rec["loss_of_functions.polyphen"].to_s != "")?sprintf("%s (%.02f)", rec["loss_of_functions.polyphen"], rec["variation_annotations.polyphen_score"]):nil,
			"SIFT"     => (rec["loss_of_functions.sift"].to_s != "")?sprintf("%s (%.02f)", rec["loss_of_functions.sift"], rec["variation_annotations.sift_score"]):nil
		}
	end
	
end