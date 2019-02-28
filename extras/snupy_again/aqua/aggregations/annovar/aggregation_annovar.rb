class AggregationAnnovar < Aggregation
	
	@@color_consequence = {
		/.*chromosome.*/                   => "salmon",
		/.*exon_loss_variant.*/            => "salmon",
		/.*frameshift_variant.*/           => "salmon",
		/.*rare_amino_acid_variant.*/      => "salmon",
		/.*splice_acceptor_variant.*/      => "salmon",
		/.*splice_donor_variant.*/         => "salmon",
		/.*stop_lost.*/                    => "salmon",
		/.*start_lost.*/                   => "salmon",
		/.*stop_gained.*/                  => "salmon",
		/.*TF_binding_site_variant.*/      => "#ffff99",
		/.*coding_sequence_variant.*/      => "#ffff99",
		/.*inframe_insertion.*/            => "#ffff99",
		/.*disruptive_inframe_insertion.*/ => "#ffff99",
		/.*inframe_deletion.*/             => "#ffff99",
		/.*disruptive_inframe_deletion.*/  => "#ffff99",
		/.*missense_variant.*/             => "#ffff99",
		/.*splice_region_variant.*/        => "#ffff99",
		/.*3_prime_UTR_truncation.*/       => "#ffff99",
		/.*5_prime_UTR_truncation.*/       => "#ffff99"
	}
	
	batch_attributes(Annovar)
	
	register_aggregation :ensembl_gene_id,
	                     label:              "Ensembl Gene Id",
	                     colname:            "Ensembl Gene Id (AnnoVar)",
	                     colindex:           3.1,
	                     aggregation_method: lambda {|rec| linkout({label: rec["annovars.ensembl_gene"], url: "http://jan2013.archive.ensembl.org//Homo_sapiens/Gene/Summary?t=#{rec["annovars.ensembl_gene"]}"})},
	                     type:               :attribute,
	                     checked:            false,
	                     category:           "AnnoVar",
	                     requires:           {
		                     Annovar => [:ensembl_gene]
	                     }
	
	register_aggregation :refgene_gene,
	                     label:              "RefSeq Gene",
	                     colname:            "RefSeq Gene Symbol (AnnoVar)",
	                     colindex:           1.2,
	                     aggregation_method: lambda {|rec| linkout({label: rec["annovars.refgene_gene"], url: "http://www.ncbi.nlm.nih.gov/gene/?term=#{rec["annovars.refgene_gene"]}[sym]"})},
	                     type:               :attribute,
	                     checked:            false,
	                     category:           "AnnoVar",
	                     record_color:       {
		                     "RefSeq Gene Symbol (AnnoVar)" => :factor_norm
	                     },
	                     requires:           {
		                     Annovar => [:refgene_gene]
	                     }
	
	register_aggregation :annotation,
	                     label:              "Consequence (Ensembl v75)",
	                     colname:            "Consequence (AnnoVar-Ensembl)",
	                     colindex:           1.62,
	                     checked:            true,
	                     aggregation_method: lambda {|rec| "#{rec["annovars.ensembl_annovar_annotation"]} (#{rec["annovars.ensembl_annotation"]})"},
	                     type:               :attribute,
	                     category:           "AnnoVar",
	                     record_color:       {
		                     "Consequence (AnnoVar-Ensembl)" => {
			                     /stopgain.*/      => "salmon",
			                     /stoploss.*/      => "salmon",
			                     /nonsynonymous.*/ => "#ffff99",
			                     #/UTR.*/ => "#ffff99",
			                     /splicing.*/ => "#ffff99"
		                     }.merge(@@color_consequence)
	                     },
	                     requires:           {
		                     Annovar => [:ensembl_annotation, :ensembl_annovar_annotation]
	                     }
	register_aggregation :annotation_refgene,
	                     label:              "Consequence (RefSeq)",
	                     colname:            "Consequence (AnnoVar-RefSeq)",
	                     colindex:           1.621,
	                     checked:            true,
	                     aggregation_method: lambda {|rec| "#{rec["annovars.refgene_annovar_annotation"]} (#{rec["annovars.refgene_annotation"]})"},
	                     type:               :attribute,
	                     category:           "AnnoVar",
	                     record_color:       {
		                     "Consequence (AnnoVar-RefSeq)" => {
			                     /stopgain.*/      => "salmon",
			                     /stoploss.*/      => "salmon",
			                     /nonsynonymous.*/ => "#ffff99",
			                     #/UTR.*/ => "#ffff99",
			                     /splicing.*/ => "#ffff99"
		                     }.merge(@@color_consequence)
	                     },
	                     requires:           {
		                     Annovar => [:refgene_annotation, :refgene_annovar_annotation]
	                     }
	
	register_aggregation :tfbs,
	                     label:              "Transcription Factor Binding Site",
	                     colname:            "TFBS (AnnoVar)",
	                     colindex:           6,
	                     aggregation_method: lambda {|rec|
		                     return "" if rec["annovars.tfbs_motif_name"].nil?
		                     linkout({
			                             label: "#{rec["annovars.tfbs_motif_name"]}(#{rec["annovars.tfbs_score"]})",
			                             url:   "http://www.broadinstitute.org/gsea/msigdb/cards/#{rec["annovars.tfbs_motif_name"]}"
		                             })
	                     },
	                     type:               :attribute,
	                     category:           "AnnoVar",
	                     color:              {
		                     "TFBS (AnnoVar)" => {/.+/ => "#ffff99"}
	                     },
	                     requires:           {
		                     Annovar => [:tfbs_motif_name, :tfbs_score]
	                     }
	register_aggregation :popfreq,
	                     label:              "Population Frequency",
	                     colname:            "Pop. Freq. (Annovar)",
	                     colindex:           7.1,
	                     aggregation_method: :aggregate_requirements,
	                     type:               :attribute,
	                     checked:            true,
	                     category:           "AnnoVar",
	                     color:              {
		                     /Pop. Freq. \(Annovar\).*/ => create_color_gradient([0, 0.15, 1], colors = ["salmon", "lightyellow", "palegreen"])
	                     },
	                     requires:           {
		                     Annovar => [:esp6500siv2_all, :genome_2014oct, :cg69, :exac_all]
	                     }
	register_aggregation :lofp,
	                     label:              "Loss Of Function Predictions",
	                     colname:            "LoFP(Annovar)",
	                     colindex:           8.01,
	                     aggregation_method: :aggregate_requirements,
	                     type:               :attribute,
	                     checked:            true,
	                     category:           "AnnoVar",
	                     color:              {
		                     "LoFP(Annovar)[cadd_phred]"           => create_color_gradient([0, 10, 20, 100], colors = ["palegreen", "lightyellow", "lightsalmon", "salmon"]),
		                     "LoFP(Annovar)[vest3_score]"          => create_color_gradient([0, 1], colors = ["palegreen", "salmon"]),
		                     "LoFP(Annovar)[mutation_taster_pred]" => {"A" => "lightsalmon", "D" => "salmon", "P" => "lightyellow", "N" => "lightyellow"}, #http://annovar.openbioinformatics.org/en/latest/user-guide/filter/#-mutationtaster-annotation
		                     "LoFP(Annovar)[mutation_assessor_pred]" => {"M" => "lightsalmon", "H" => "salmon", "L" => "lightyellow", "N" => "palegreen"}, # http://mutationassessor.org/howitworks.php
		                     "LoFP(Annovar)[polyphen2_hvar_pred]" => {"D" => "salmon", "P" => "lightsalmon", "T" => "palegreen", "B" => "palegreen"},
		                     "LoFP(Annovar)[polyphen2_hdvi_pred]" => {"D" => "salmon", "P" => "lightsalmon", "T" => "palegreen", "B" => "palegreen"},
		                     /LoFP\(Annovar\)\[.*\]/              => {"D" => "salmon", "N" => "palegreen", "T" => "palegreen", "A" => "lightsalmon", "B" => "palegreen"}
	                     },
	                     requires:           {
		                     Annovar => [:polyphen2_hvar_pred, :polyphen2_hdvi_pred, :sift_pred, :mutation_taster_pred, :mutation_assessor_pred, :fathmm_pred, :radial_svm_pred, :lrt_pred, :vest3_score, :cadd_phred]
	                     }
	
	register_aggregation :conservation,
	                     label:              "Conservation Scores",
	                     colname:            "Conservation(Annovar)",
	                     colindex:           8.1,
	                     aggregation_method: :aggregate_requirements,
	                     type:               :attribute,
	                     checked:            true,
	                     category:           "AnnoVar",
	                     color:              {
		                     "Conservation(Annovar)[gerp_rs]" => create_color_gradient([-12, 0, 2, 6], colors = ["palegreen", "lightyellow", "lightsalmon", "salmon"]), # http://rohsdb.cmb.usc.edu/GBshape/cgi-bin/hgTables?db=hg19&hgta_group=compGeno&hgta_track=allHg19RS_BW&hgta_table=allHg19RS_BW&hgta_doSchema=describe+table+schema
		                     "Conservation(Annovar)[phylop46way_placental]"   => create_color_gradient([-10, 0, 1.5, 3], colors = ["palegreen", "lightyellow", "lightsalmon", "salmon"]),
		                     "Conservation(Annovar)[phylop100way_vertebrate]" => create_color_gradient([-10, 0, 1.5, 3], colors = ["palegreen", "lightyellow", "lightsalmon", "salmon"]),
		                     "Conservation(Annovar)[siphy_29way_logOdds]"     => create_color_gradient([-10, 0, 2, 4], colors = ["palegreen", "lightyellow", "lightsalmon", "salmon"])
	                     },
	                     requires:           {
		                     Annovar => [:gerp_rs, :phylop46way_placental, :phylop100way_vertebrate, :siphy_29way_logOdds]
	                     }
	
	register_aggregation :clinical,
	                     label:              "Clinical significance",
	                     colname:            "Clin. Sign. (Annovar)",
	                     colindex:           9,
	                     aggregation_method: :aggregate_requirements,
	                     type:               :attribute,
	                     checked:            false,
	                     category:           "AnnoVar",
	                     color:              {
		                     "Clin. Sign. (Annovar)" => {"pathogenic" => "salmon"}
	                     },
	                     requires:           {
		                     Annovar => [:variant_clinical_significance, :variant_disease_name, :variant_accession_versions]
	                     }
	register_aggregation :clinical_gwas,
	                     label:              "GWAS catalog",
	                     colname:            "GWAS (Annovar)",
	                     colindex:           9.1,
	                     aggregation_method: :aggregate_requirements,
	                     type:               :attribute,
	                     checked:            false,
	                     category:           "AnnoVar",
	                     requires:           {
		                     Annovar => [:gwas_catalog]
	                     }
	register_aggregation :clinical_tissue,
	                     label:              "COSMIC tissues",
	                     colname:            "COSMIC tissue (Annovar)",
	                     colindex:           9.1,
	                     aggregation_method: lambda {|rec|
		                     rec["annovars.cosmic68_occurence"].to_s.split(",").map(&:strip)
	                     },
	                     type:               :attribute,
	                     checked:            false,
	                     category:           "AnnoVar",
	                     record_color:       {
		                     "COSMIC tissue (Annovar)" => {
			                     /^[0-9]{4,}/ => "red", # four digits
			                     /^[0-9]{3,}/ => "salmon", # three digits
			                     /^[0-9]{2,}/ => "#ffff99", # two digists
			                     /^[0-9]{1,}/ => "palegreen" # 1 digit
		                     }
	                     },
	                     requires:           {
		                     Annovar => [:cosmic68_occurence]
	                     }
	register_aggregation :mirna,
	                     label:              "MicroRNA Target",
	                     colname:            "miRNA target",
	                     colindex:           10,
	                     aggregation_method: lambda {|rec|
		                     gene, mirna = rec["annovars.micro_rna_target_name"].to_s.split(/[:]/)
		                     {
			                     gene:  gene.to_s,
			                     mirna: mirna,
			                     score: rec["annovars.micro_rna_target_score"]
		                     }
	                     },
	                     type:               :attribute,
	                     checked:            false,
	                     category:           "AnnoVar",
	                     color:              {
		                     "miRNA target[score]" => create_color_gradient([0, 50, 100], colors = ["palegreen", "lightyellow", "salmon"])
	                     },
	                     requires:           {
		                     Annovar => [:micro_rna_target_name, :micro_rna_target_score]
	                     }
	
	register_aggregation :annovar_summary,
	                     label:              "Summary",
	                     colname:            "Annovar summary",
	                     colindex:           7.1,
	                     prehook:            :get_summary,
	                     aggregation_method: :add_summary,
	                     type:               :attribute,
	                     checked:            false,
	                     active:             false,
	                     category:           "AnnoVar",
	                     color:              {
		                     /Annovar summary.*qscore_phred.*/ => create_color_gradient([-10, 3, 13, 40], colors = ["palegreen", "lightyellow", "salmon", "indianred"]),
		                     /Annovar summary.*qscore.*/ => create_color_gradient([-13, 0, 13], colors = ["palegreen", "lightyellow", "salmon"]),
		                     /Annovar summary.*/ => create_color_gradient([0, 0.5, 0.95, 1], colors = ["palegreen", "lightyellow", "salmon", "indianred"])
	                     },
	                     requires:           {
		                     Annovar => [:variation_id]
	                     }
	
#	register_aggregation :annovar_quantiles,
#	                     active: false,
#	                     label:              "Quantiles",
#	                     colname:            "Annovar Quantiles",
#	                     prehook:            :get_quantiles,
#	                     aggregation_method: :add_quantiles,
#	                     type:               :attribute,
#	                     checked:            true,
#	                     category:           "AnnoVar",
#	                     color: Hash[AnnovarAnnotation.configuration(:quantiles)[Annovar].map{|attr, dir|
#		                     if dir > 0 then
#		                        ["Annovar Quantiles[#{attr}]", create_color_gradient([0, 0.5, 1], colors = ["palegreen", "lightyellow", "salmon"])]
#		                     else
#			                     ["Annovar Quantiles[#{attr}]", create_color_gradient([0, 0.5, 1], colors = ["salmon", "lightyellow", "palegreen"])]
#							 end
#	                     }],
#	                     requires:           {
#		                     Annovar => AnnovarAnnotation.configuration(:quantiles).map {|model, attributes_directions| attributes_directions.keys}.flatten
#	                     }
#
#	def get_quantiles_to_delete(rows, params)
#		@quantiles = {}
#		AnnovarAnnotation.quantile_estimates(params[:organism_id]).each do |quant|
#			@quantiles[quant.attribute_column] = quant
#		end
#	end
#
#	def add_quantiles(rec)
#		rec["Annovar Quantiles"] = Hash[@quantiles.map{|attr, quant|
#			val = rec["annovars.#{attr}"]
#			estimate = quant.estimate(val).to_f.round(3)
#			[attr, estimate]
#		}]
#	end
	
	def get_summary(rows, params)
		if params[:experiment].nil? then
			@summary = {}
			return
		end
		organismid = Experiment.find(params[:experiment]).organism_id
		varids     = rows.map {|id, recs| recs.map {|rec| rec["annovars.variation_id"]}}.flatten.uniq
		@summary   = Annovar.summary(varids, organismid)
	end
	
	def add_summary(rec)
		varid                  = rec["annovars.variation_id"]
		rec["Annovar summary"] = @summary[varid] || {}
	end
	
	def aggregate_requirements(rec)
		ret     = {}
		popcols = [:esp6500siv2_all, :genome_2014oct, :cg69, :exac_all]
		self.requirements[Annovar].each do |colname|
			ret[colname] = rec["annovars.#{colname}"]
			if popcols.include?(colname) then
				ret[colname] = 0 if ret[colname].to_s == ""
			end
		
		end
		ret
	end


end
