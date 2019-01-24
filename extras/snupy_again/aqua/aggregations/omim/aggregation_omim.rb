class AggregationOmim < Aggregation
	# provide all attributes of a model through the AQuA API
	# batch_attributes(Omim)
	
	
	register_aggregation :aggregation_omim,
						 label: "Phenotype",
						 colname: "Omim Phenotype",
						 prehook: :cache_gene2pheno, # OPTIONAL used for calculation that need to happen before the aggregation. Such as counting. :posthook is also possible to modify array after aggregation.
						 colindex: 20,
						 aggregation_method: :omim_phenotype,
						 type: :attribute,
						 checked: true,
						 category: "OMIM",
						 requires: {
							 Vep::Ensembl => [:gene_symbol]#OmimGenemap => [:phenotype, :symbol]
						 },
		                 active: true # use this to activate your query once it is ready
	
	register_aggregation :aggregation_omim1,
						 label: "Some other label",
						 colname: "Some other attr",
						 colindex: 3.1,
						 aggregation_method: lambda{|rec|
							rec["some_attribute"]
						 },
						 type: :attribute,
						 record_color: {
							 "Some other attr" => :factor
						 },
						 checked: true,
						 category: :omim,
						 requires: {
							 OmimGenemap => ["some_attribute"]
						 },
						 active: false # use this to activate your query once it is ready
	
	def omim_phenotype(rec)
		# rec["Omim Phenotype"] = @gene2pheno[rec[Vep::Ensembl.colname("gene_symbol")]]
		@gene2pheno[rec[Vep::Ensembl.colname("gene_symbol")]]
	end
	
	def cache_gene2pheno(arr, params)
		@gene2pheno = {}
		# group key is used to group records of the database into groups, such as by variantion_id or by overlapping region
		genes = arr.map {|groupkey, recs|
			recs.map {|rec|
				rec[Vep::Ensembl.colname("gene_symbol")]
				#@gene2pheno[rec[Vep::Ensembl.colname("gene_symbol")]] ||= []
				#@gene2pheno[rec[Vep::Ensembl.colname("gene_symbol")]]
			}
		}.flatten.uniq.reject(&:nil?).reject{|x| x == ""}
		return if params["experiment"].nil?
		organism = params["experiment"].organism
		symbol_col = :symbol if organism.id == Aqua.organisms(:human).id
		symbol_col = :mgi_symbol if organism.id == Aqua.organisms(:mouse).id
		
		OmimGenemap.where(symbol_col => genes).select([:phenotype_raw, symbol_col]).uniq.each do |genemap|
			@gene2pheno[genemap[symbol_col]] ||= []
			@gene2pheno[genemap[symbol_col]] << genemap.phenotype_raw
		end
	end

end