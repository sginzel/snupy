class QueryGeneratorCompoundHeterozygous < QueryGenerator

	config_generator label: "Compund heterozygous",
									 requires: {},
									 options: {
											 exclude_siblings: false,
											 tool:             Tag.where(category: "TOOL").pluck(:value),
											 annotation:       %w(VepEnsembl VepRefSeq SnpEff AnnovarEnsembl AnnovarRefSeq)
									 }

	
	def yesno(x, y)
		if (x == y)
			'1'
		else
			'0'
		end
	end
	
	def get_parameters()

		@params[:exclude_siblings] = false if @params[:exclude_siblings].nil?
		@params[:tool] = "GATK" if @params[:tool].nil?
		@params[:annotation] = 'VepEnsembl' if @params[:annotation].nil?
		use_siblings = (@params[:exclude_siblings] == "1")?"1":"0"

		# find parents
		parents = @entity.parents
		if @params[:exclude_siblings] then
			siblings = @entity.siblings
		else
			siblings = Entity.where("1 = 0")
		end

		# now find the sample ids that belong to the submitted tool
		smpls          = @entity.samples.joins(:vcf_file => :tags).where("tags.value" => @params[:tool]).pluck("samples.id")
		smpls_parents  = parents.map{|e|  e.samples.joins(:vcf_file => :tags).where("tags.value" => @params[:tool]).pluck("samples.id")}.flatten
		smpls_siblings = siblings.map{|e| e.samples.joins(:vcf_file => :tags).where("tags.value" => @params[:tool]).pluck("samples.id")}.flatten

		if (smpls.size == 0) then
			add_info("No samples found.")
			return nil
		end

		if (smpls_parents.size != 2) then
			add_info("Found ##{smpls_parents.size} samples(#{Sample.where(id: smpls_parents).pluck(:name)}) as parents. Only 2 parent samples allowed")
			return nil
		end

		add_info("USING: #{Sample.where(id: smpls_parents).pluck(:name)} as parents")
		add_info("USING: #{Sample.where(id: smpls_siblings).pluck(:name)} as siblings") if use_siblings

		all_aggregations = {}
		aquaagg = Aqua.aggregations
		aquaagg.keys.each do |aggklass|
			aggklassname = aggklass.name.underscore
			all_aggregations[aggklassname] = {}
			aquaagg[aggklass].each do |k, aggattr|
				next if aggattr[:type].to_s != "attribute"
				all_aggregations[aggklassname][k.to_s] = "1"
			end
		end
		
		consequence_filters = {
			"FilterAnnovarConsequence" =>
			   {"consequence"               => yesno(@params[:annotation], 'AnnovarEnsembl'),
				"consequence_refgene"       => yesno(@params[:annotation], 'AnnovarRefSeq'),
				"consequence_contradicting" => "0"},
		   "FilterSnpEffConsequence"  => {"consequence" => yesno(@params[:annotation], 'SnpEff')},
		   "VepFilterConsequence"     =>
			   {"consequence"               => yesno(@params[:annotation], 'VepEnsembl'),
				"consequence_refseq"        => yesno(@params[:annotation], 'VepRefSeq'),
				"consequence_severe"        => "0",
				"consequence_severe_refseq" => "0",
				"consequence_severe_cnv"    => "0"}
			}
		compound_het_filters = {
			"FilterSample" =>
				{"compound_heterozygous_snpeff"     => yesno(@params[:annotation], 'SnpEff'),
				 "compound_heterozygous_annovar"    => yesno(@params[:annotation], 'AnnovarEnsembl'),
				 "compound_heterozygous_vepensembl" => yesno(@params[:annotation], 'VepEnsembl'),
				 "compound_heterozygous_veprefseq"  => yesno(@params[:annotation], 'VepRefSeq')}
			}
		
		query_process = {
				samples: smpls,
				queries:
						{
								"query_variation_call"    =>
										{"read_depth"       =>
												 {"value"   => "10",
													"filters" => {"FilterVariationCall" => {"vcdp" => "1"}
													},
													"combine" => "AND"},
										 "genotype"         =>
												 {"value"   => "0/1,0|1,1|0,1/2,1|2,2|1",
													"filters" => {"FilterVariationCall" => {"vcgt" => "1"}
													},
													"combine" => "AND"},
										 "genotype_quality" =>
												 {"value"   => "60",
													"filters" => {"FilterVariationCall" => {"vcgq" => "1"}
													},
													"combine" => "AND"},
										},
								"query_consequence"       =>
										{"consequence" =>
												 {"value"   =>
															"frameshift_variant,incomplete_terminal_codon_variant,inframe_deletion,inframe_insertion,initiator_codon_variant,mature_miRNA_variant,missense_variant,splice_acceptor_variant,splice_donor_variant,start_lost,5_prime_UTR_premature_start_codon_gain_variant,stop_gained,stop_lost,stop_retained_variant,TF_binding_site_variant,TFBS_ablation",
													"filters" => consequence_filters,
													"combine" => "OR"}
										},
								"query_sample"            =>
										{"not_present_in_any"    =>
												 {"value"   => smpls_siblings.join(","),
													"filters" =>
															{"FilterSample" => {"not_present_in_gq" => use_siblings, "not_present_in" => "0"}
															},
													"combine" => "AND"},
										 "heterozygous_in_all"   =>
												 {"value"   => "",
													"filters" =>
															{"FilterSample" =>
																	 {"heterozygous_all_gq75" => "0", "heterozygous_all_gq0" => "0"}
															},
													"combine" => "AND"},
										 "compound_heterozygous" =>
												 {"value"   => "#{smpls_parents.join(",")}",
													"filters" => compound_het_filters,
													"combine" => "AND"}
										},
								"query_simple_population" =>
										{"population_frequency" =>
												 {"value"   => "0.01",
													"filters" =>
															{"FilterAnnovarPopulation" =>
																	 {"annovar_onekg"   => "0",
																		"annovar_cd69"    => "0",
																		"annovar_esp6500" => "0",
																		"annovar_exac"    => "0"},
															 "VepFilterVariant"        => {"vep_onekg" => "1", "vep_exac" => "1"}
															},
													"combine" => "AND"}
										},
								"query_gene_feature"=>
										{"is_canonical"=>
												 {"combine"=>"OR",
													"value"=>true,
													"filters"=>{"VepFilterVariant"=>{"vep_canonical"=>"1"}}}}
						},
				aggregations: {
						"group"=>
								{"aggregation_group_by"=>
										 {"group_by_variation"=>"1", "group_by_overlap"=>"0"}},
						"attribute"=> all_aggregations
				}
		}
		query_process
	end
end