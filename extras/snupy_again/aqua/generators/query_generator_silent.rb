class QueryGeneratorSilent < QueryGenerator

	config_generator label: "Impactful Silent Mutations (BETA)",
									 requires: {},
									 options: {
											 exclude_controls: true,
											 tool: ["GATK", "Varscan2", "Mutect"]
									 }


	def get_parameters
		@params[:exclude_controls] = "0" if @params[:exclude_controls].nil?
		@params[:tool] = "GATK" if @params[:tool].nil?

		tool = @params[:tool]

		# find controls
		parents = @entity.parents
		if @params[:exclude_siblings] == "1" then
			siblings = @entity.siblings
		else
			siblings = Entity.where("1 = 0")
		end

		# now find the sample ids that belong to the submitted tool
		smpls          = @entity.samples.joins(:vcf_file => :tags).where("tags.value" => @params[:tool]).pluck("samples.id")
		# if varscan is selected, use denovo and somatics
		if tool == "Varscan2"
			smpls = Sample.where(id: smpls).joins(:tags).where("tags.value"=> ["denovo", "somatic"]).pluck("samples.id")
		end

		if (smpls.size == 0) then
			add_info("No samples found.")
			return nil
		else
			add_info("#{smpls.size} #{@params[:tool]} samples.")
		end

		smpls_control = []
		smpls_control += siblings.map{|e| e.samples.joins(:vcf_file => :tags).where("tags.value" => @params[:tool]).pluck("samples.id")}.flatten
		smpls_control += parents.map{|e|  e.samples.joins(:vcf_file => :tags).where("tags.value" => @params[:tool]).pluck("samples.id")}.flatten
		use_controls =  (@params[:exclude_controls] == "1")?"1":"0"
		if (use_controls == "1") then
			if (smpls_control.size == 0) then
				add_info("No control samples found.")
			else
				add_info("#{smpls_control.size} controls used.")
			end
		else
			add_info("Controls not used.")
		end


		query_process = {
				submited_params: @params,
				samples: smpls,
				queries:
						{"query_variation_call"=>
								 {"read_depth"=>
											{"combine"=>"AND",
											 "value"=>20,
											 "filters"=>{"FilterVariationCall"=>{"vcdp"=>"1"}}}},
						 "query_consequence"=>
								 {"consequence"=>
											{"combine"=>"OR",
											 "value"=> "non_coding_transcript_exon_variant,3_prime_UTR_variant,5_prime_UTR_variant,inframe_deletion,inframe_insertion,intron_variant,splice_region_variant,synonymous_variant",
											 "filters"=>{"VepFilterConsequence"=>{"consequence_severe"=>"1"}}}},
						 "query_simple_population"=>
								 {"population_frequency"=>
											{"combine"=>"AND",
											 "value"=>0.001,
											 "filters"=>{"VepFilterVariant"=>{"vep_exac"=>"1"}}}},
						 "query_cadd"=>
								 {"query_cadd"=>
											{"combine"=>"OR",
											 "value"=>25,
											 "filters"=>{"FilterCadd"=>{"cadd_phred_score"=>"1"}}}},
						 "query_gene_feature"=>
								 {"is_canonical"=>
											{"combine"=>"OR",
											 "value"=>true,
											 "filters"=>{"VepFilterVariant"=>{"vep_canonical"=>"1"}}}}},
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