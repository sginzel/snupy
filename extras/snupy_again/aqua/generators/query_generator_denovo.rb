class QueryGeneratorDenovo < QueryGenerator

	config_generator label: "De-Novo Mutations",
									 requires: {},
									 options: {
											 exclude_siblings: false,
											 tool: ["Varscan2", "GATK"]
									 }


	def get_parameters

		@params[:exclude_siblings] = false if @params[:exclude_siblings].nil?
		@params[:tool] = "Varscan2" if @params[:tool].nil?

		tool = @params[:tool]

		# find parents
		parents = @entity.parents
		if @params[:exclude_siblings] == "1" then
			siblings = @entity.siblings
		else
			siblings = Entity.where("1 = 0")
		end

		# now find the sample ids that belong to the submitted tool
		smpls          = @entity.samples.joins(:vcf_file => :tags).where("tags.value" => @params[:tool]).pluck("samples.id")
		smpls = Sample.where(id: smpls).joins(:tags).where("tags.value"=> "denovo").pluck("samples.id") if tool == "Varscan2"
		smpls_siblings = siblings.map{|e| e.samples.joins(:vcf_file => :tags).where("tags.value" => @params[:tool]).pluck("samples.id")}.flatten

		if (smpls.size == 0) then
			add_info("No samples found.")
			return nil
		end

		use_siblings = (@params[:exclude_siblings] == "1")?"1":"0"

		if tool == "GATK" then
			smpls_parents  = parents.map{|e|  e.samples.joins(:vcf_file => :tags).where("tags.value" => @params[:tool]).pluck("samples.id")}.flatten
			if (smpls_parents.size != 2) then
				add_info("Found ##{smpls_parents.size} samples(#{Sample.where(id: smpls_parents).pluck(:name)}) as parents. Only 2 parent samples allowed")
				return nil
			end
			add_info("USING: #{Sample.where(id: smpls_parents).pluck(:name)} as parents")
		else
			smpls_parents = []
		end
		add_info("USING: #{Sample.where(id: smpls_siblings).pluck(:name)} as siblings") if use_siblings



		query_process = {
				submited_params: @params,
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
												 {"value"   => "",
													"filters" => {"FilterVariationCall" => {"vcgt" => "1"}
													},
													"combine" => "AND"},
										 "genotype_quality" =>
												 {"value"   => "",
													"filters" => {"FilterVariationCall" => {"vcgq" => "1"}
													},
													"combine" => "AND"},
										},
								"query_consequence"       =>
										{"consequence" =>
												 {"value"   =>
															"frameshift_variant,incomplete_terminal_codon_variant,inframe_deletion,inframe_insertion,initiator_codon_variant,mature_miRNA_variant,missense_variant,splice_acceptor_variant,splice_donor_variant,start_lost,5_prime_UTR_premature_start_codon_gain_variant,stop_gained,stop_lost,stop_retained_variant,TF_binding_site_variant,TFBS_ablation",
													"filters" =>
															{"FilterAnnovarConsequence" =>
																	 {"consequence"               => "0",
																		"consequence_refgene"       => "0",
																		"consequence_contradicting" => "0"},
															 "FilterSnpEffConsequence"  => {"consequence" => "0"},
															 "VepFilterConsequence"     =>
																	 {"consequence"               => "0",
																		"consequence_refseq"        => "0",
																		"consequence_severe"        => "1",
																		"consequence_severe_refseq" => "0",
																		"consequence_severe_cnv"    => "0"}},
													"combine" => "OR"}
										},
								"query_sample"            =>
										{"not_present_in_any"    =>
												 {"value"   => ([smpls_parents + smpls_siblings].join(",")),
													"filters" =>
															{"FilterSample" => {"not_present_in_gq" => use_siblings, "not_present_in" => "0"}
															},
													"combine" => "AND"},
										 "heterozygous_in_all"   =>
												 {"value"   => "",
													"filters" =>
															{"FilterSample" =>
																	 {"heterozygous_all_gq75" => "1", "heterozygous_all_gq0" => "0"}
															},
													"combine" => "AND"},
										 "compound_heterozygous" =>
												 {"value"   => "",
													"filters" =>
															{"FilterSample" =>
																	 {"compound_heterozygous_snpeff"     => "0",
																		"compound_heterozygous_annovar"    => "0",
																		"compound_heterozygous_vepensembl" => "1",
																		"compound_heterozygous_veprefseq"  => "0"}
															},
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
						"attribute"=> all_aggregations()
				}
		}
		query_process
	end
end