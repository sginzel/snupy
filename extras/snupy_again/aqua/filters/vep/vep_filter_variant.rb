class VepFilterVariant < SimpleFilter
	##### Population
	create_filter_for QuerySimplePopulation, :population_frequency,
						name: :vep_onekg, 
						label: "1000 Genomes Phase 1",
						filter_method: lambda{|val| "(#{Vep::Ensembl.colname(:minor_allele_freq)} IS NULL) OR (#{Vep::Ensembl.colname(:minor_allele_freq)} <= #{val.to_f})" },
						organism: [organisms(:human)],
						checked: true, 
						requires: {
							Vep::Ensembl => [:minor_allele_freq]
						},
						tool: VepAnnotation
	create_filter_for QuerySimplePopulation, :population_frequency,
						name: :vep_exac, 
						label: "ExAc Adj. Freq.",
						filter_method: lambda{|val| "(#{Vep::Ensembl.colname(:exac_adj_maf)} IS NULL) OR (#{Vep::Ensembl.colname(:exac_adj_maf)} <= #{val.to_f})" },
						organism: [organisms(:human)],
						checked: true, 
						requires: {
							Vep::Ensembl => [:exac_adj_maf]
						},
						tool: VepAnnotation
	
	## LOSS OF FUNCTION
	create_filter_for QueryLossOfFunction, :loss_of_function,
					name: :vep_polyphen, 
					label: "PolyPhen2 HumVar",
					filter_method: lambda{|val| "#{Vep::Ensembl.colname(:polyphen_prediction)} IN ('possibly_damaging', 'probably_damaging')" },
					organism: [organisms(:human)],
					checked: true,
					requires: {
						Vep::Ensembl => [:polyphen_prediction]
					},
					tool: VepAnnotation
	create_filter_for QueryLossOfFunction, :loss_of_function,
					name: :vep_SIFT, 
					label: "SIFT (deleterious)",
					filter_method: lambda{|val| "#{Vep::Ensembl.colname(:sift_prediction)} = 'deleterious'" },
					organism: [organisms(:human), organisms(:mouse)],
					checked: true,
					requires: {
						Vep::Ensembl => [:sift_prediction]
					},
					tool: VepAnnotation
	create_filter_for QueryLossOfFunction, :loss_of_function,
					name: :vep_SIFT_lowconfidence, 
					label: "SIFT (possibly deleterious)",
					filter_method: lambda{|val| "#{Vep::Ensembl.colname(:sift_prediction)} IN ('deleterious_low_confidence', 'tolerated_low_confidence')" },
					organism: [organisms(:human), organisms(:mouse)],
					checked: false,
					requires: {
						Vep::Ensembl => [:sift_prediction]
					},
					tool: VepAnnotation
	
	## CLINICAL
	create_filter_for QueryClinicalSignificance, :clinical,
						name: :vep_clinvar, 
						label: "CLINVAR available",
						filter_method: lambda{|val| "#{Vep::Ensembl.colname(:clin_sig)} IS NOT NULL" },
						organism: [organisms(:human)],
						checked: true, 
						requires: {
							Vep::Ensembl => [:clin_sig]
						},
						tool: VepAnnotation
	create_filter_for QueryClinicalSignificance, :clinical,
						name: :vep_somatic, 
						label: "Is somatic",
						filter_method: lambda{|val| "#{Vep::Ensembl.colname(:somatic)} = 1" },
						organism: [organisms(:human)],
						checked: true, 
						requires: {
							Vep::Ensembl => [:somatic]
						},
						tool: VepAnnotation
	create_filter_for QueryClinicalSignificance, :clinical,
						name: :vep_phenotype_or_disease, 
						label: "Phenotype or Disease associated",
						filter_method: lambda{|val| "#{Vep::Ensembl.colname(:phenotype_or_disease)} = 1" },
						organism: [organisms(:human)],
						checked: true, 
						requires: {
							Vep::Ensembl => [:phenotype_or_disease]
						},
						tool: VepAnnotation
	create_filter_for QueryClinicalSignificance, :clinical,
						name: :vep_gene_pheno, 
						label: "Gene Phenotype associated",
						filter_method: lambda{|val| "#{Vep::Ensembl.colname(:gene_pheno)} = 1" },
						organism: [organisms(:human)],
						checked: true, 
						requires: {
							Vep::Ensembl => [:gene_pheno]
						},
						tool: VepAnnotation
	create_filter_for QueryClinicalSignificance, :clinical,
						name: :vep_pubmed, 
						label: "PubMed available",
						filter_method: lambda{|val| "#{Vep::Ensembl.colname(:pubmed)} IS NOT NULL" },
						organism: [organisms(:human)],
						checked: false, 
						requires: {
							Vep::Ensembl => [:pubmed]
						},
						tool: VepAnnotation
	create_filter_for QueryClinicalSignificance, :clinical,
						name: :vep_hgmd, 
						label: "HGMD",
						filter_method: lambda{|val| "#{Vep::Ensembl.colname(:dbsnp)} LIKE '%HGMD_MUTATION%'"},
						organism: [organisms(:human)],
						checked: false, 
						requires: {
							Vep::Ensembl => [:dbsnp_allele]
						},
						tool: VepAnnotation
	create_filter_for QueryClinicalSignificance, :clinical,
						name: :vep_cosmid, 
						label: "Has COSMIC ID",
						filter_method: lambda{|val| "#{Vep::Ensembl.colname(:dbsnp)} LIKE '%COSM%'" },
						organism: [organisms(:human)],
						checked: false, 
						requires: {
							Vep::Ensembl => [:dbsnp]
						},
						tool: VepAnnotation
	create_filter_for QueryGeneFeature, :is_canonical,
						name: :vep_canonical, 
						label: "Affects canonical transcript (VEP)",
						filter_method: lambda{|val| "#{Vep::Ensembl.colname(:canonical)} = 1" },
						organism: [organisms(:human), organisms(:mouse)],
						checked: true,
						requires: {
							Vep::Ensembl => [:canonical]
						},
						tool: VepAnnotation
	create_filter_for QueryClinicalSignificance, :clinical,
										name: :vep_canonical,
										label: "Affects canonical transcript (deprecated)",
										filter_method: lambda{|val| "#{Vep::Ensembl.colname(:canonical)} = 1" },
										organism: [organisms(:human), organisms(:mouse)],
										checked: false,
										requires: {
												Vep::Ensembl => [:canonical]
										},
										tool: VepAnnotation
	## Other Features
end
