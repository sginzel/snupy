# == Description
# Queries for clinical features
class QueryClinicalSignificance < SimpleQuery
	register_query :clinical, 
								 label: "Has clinical significance",
								 default: "0",
								 type: :checkbox,
								 organism: [@@ORGANISMS[:human], @@ORGANISMS[:mouse]], 
								 priority: 100,
								 combine: "OR",
								 group: "Clinical"
	register_query :clinical_omim_disease,
	               label: "OMIM Phenotype",
	               default: [],
	               type: :collection,
	               organism: [@@ORGANISMS[:human], @@ORGANISMS[:mouse]],
	               priority: 100.1,
	               combine: "AND",
	               group: "Clinical"

	register_query :clinical_clinvar,
								 label: "ClinVar Association",
								 default: [],
								 type: :collection,
								 organism: [@@ORGANISMS[:human]],
								 priority: 100.2,
								 combine: "AND",
								 group: "Clinical"

	register_query :clinical_association,
								 label: "Clinical association",
								 default: [],
								 type: :collection,
								 organism: [@@ORGANISMS[:human], @@ORGANISMS[:mouse]],
								 priority: 100.5,
								 combine: "OR",
								 group: "Clinical"
	register_query :clinical_disease,
							 label: "Disease association",
							 default: [],
							 type: :collection,
							 organism: [@@ORGANISMS[:human], @@ORGANISMS[:mouse]],
							 priority: 101,
							 combine: "AND",
								 group: "Clinical"
	register_query :clinical_tissue,
							 label: "Observed in tissue",
							 default: "",
							 type: :collection,
							 organism: [@@ORGANISMS[:human], @@ORGANISMS[:mouse]],
							 priority: 102,
							 combine: "AND",
								 group: "Clinical"
end