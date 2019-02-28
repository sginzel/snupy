class QueryGeneratorOncogenome < QueryGenerator
	
	config_generator label: "Oncogenome",
					 requires: {},
					 options: {
						 tool:  ["Somatic", "Varscan2", "Mutect"],
						 read_depth: "10",
						 population_frequency: "0.01",
						 tag: SpecimenProbe.available_tags(true)["STATUS"].map(&:value)
					 }
	
	
	def get_tag
		@params[:tag]
	end
	
	def get_parameters
		
		@params[:tool] = "Somatic" if @params[:tool].nil?
		
		if @params[:tool] == "Somatic"
			tools =  ["Varscan2", "Mutect"]
		else
			tools = @params[:tool]
		end
		somatic_smpls = SnupyAgain::TagExpression.parse("Somatic").values.flatten.map(&:id)
		
		specimens = SnupyAgain::TagExpression.parse(get_tag()).values.flatten.map(&:id)
		
		# now find the sample ids that belong to the submitted tool
		smpls_tool          = @entity.samples.joins(:vcf_file => :tags).where(specimen_probe_id: specimens).where("tags.value" => tools).pluck("samples.id")
		smpls_somatic       = @entity.samples.where(specimen_probe_id: specimens).pluck('samples.id') & somatic_smpls
		smpls = (smpls_tool & smpls_somatic).uniq
		
		if (smpls.size == 0) then
			add_info("No samples found for #{get_tag} with tool #{tools}.")
			return nil
		end

		add_info("USING: #{Sample.where(id: smpls).pluck(:name)} as somatic samples")

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
		
		query_process = {
			submited_params: @params,
			samples: smpls,
			queries:
				{
					"query_variation_call"    =>
						{"read_depth"       =>
							 {"value"   => @params[:read_depth],
							  "filters" => {"FilterVariationCall" => {"vcdp" => "1"}
							  },
							  "combine" => "AND"},
						 "genotype"         =>
							 {"value"   => "1/1,1|1",
							  "filters" => {"FilterVariationCall" => {"vcgt" => "0"}
							  },
							  "combine" => "AND"},
						 "genotype_quality" =>
							 {"value"   => "60",
							  "filters" => {"FilterVariationCall" => {"vcgq" => "0"}
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
							 {"value"   => "",
							  "filters" =>
								  {"FilterSample" => {"not_present_in_gq" => "0", "not_present_in" => "0"}
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
							 {"value"   => @params[:population_frequency],
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
