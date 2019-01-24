class FilterOmim < SimpleFilter
	# filter_method can be a symbol for a method
	#               or a lambda: lambda{|value| "some_model_column IN (#{value.join(",")})"}
	create_filter_for QueryClinicalSignificance, :clinical_omim_disease,
					  name: :omim_phenotype,
					  label: "OMIM phenotype association",
					  filter_method: :omim_phenotype,
					  collection_method: :find_phenotypes,
					  organism: [organisms(:human), organisms(:mouse)],
					  checked: true,
					  requires: {
						  Vep::Ensembl => [:gene_symbol]#,
					  },
					  tool: OmimAnnotation,
					  active: true # use this to activate your filter once it is ready
	
	# return a SQL condition here.
	def omim_phenotype(value, params)
		# find genes afffecting phenotpe
		organism = Experiment.find(params["experiment"]).organism
		symbols = []
		if organism.name == "homo sapiens" then
			# use approved symbol
			symbols = OmimGenemap.where("phenotype IN (#{value.join(",")})").uniq(:symbol).pluck(:symbol)
		elsif organism.name == "mus musculus" then
			# use mgi column
			symbols = OmimGenemap.where("phenotype IN (#{value.join(",")})").uniq(:mgi_symbol).pluck(:mgi_symbol)
		end
		symbols.reject!{|sym| sym.to_s == ""}
		return nil if symbols.size == 0
		sql = "#{Vep::Ensembl.colname(:gene_symbol)} IN (#{symbols.map{|s| "'#{s}'"}.join(",")})"
		sql
	end
	
	# in case of ComplexFilter - filter the array
	# def some_filter_method(arr, value)
	# 	arr.select{|rec| rec['some_attr'] == value}
	# end
	
	# returns a array of hashes containting
	def find_phenotypes(params)
		organism = Experiment.find(params["experiment"]).organism
		symbol_col = :symbol if organism.id == Aqua.organisms(:human).id
		symbol_col = :mgi_symbol if organism.id == Aqua.organisms(:mouse).id
		pheno2genes = {}
		OmimGenemap.select([:phenotype, symbol_col]).uniq.each do |genemap|
			next if genemap.phenotype.to_s == ""
			next if genemap[symbol_col].to_s == ""
			pheno2genes[genemap.phenotype] ||= []
			pheno2genes[genemap.phenotype] << genemap[symbol_col]
		end
		pheno2genes.map{|phenotype, genes|
			{
				id: phenotype,
				phenotype: phenotype,
				genes: genes
			}
		}
	end
	
	def applicable?(organismid = nil)
		is_applicable = super
		# this may be used to check if other models exist or not.
		# check_some_other_thing = !defined?(SomeOtherModel).nil? # example
		check_some_other_thing = true
		is_applicable && check_some_other_thing
	end
end
