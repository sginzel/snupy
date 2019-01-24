# == Description
# Queries for variants that lead to potential gain of function
class QueryAminoAcidExchanges < SimpleQuery
	register_query :amino_acid, 
								 label: "Amino acid exchange",
								 default: "",
								 type: :collection,
								 organism: [@@ORGANISMS[:human], @@ORGANISMS[:mouse]], 
								 priority: 50.2,
								 combine: "OR",
								 group: "Protein"
	register_query :impactful_amino_acid_exchanges, 
								 label: "Impactful amino acid exchanges",
								 default: "0",
								 type: :checkbox,
								 organism: [@@ORGANISMS[:human], @@ORGANISMS[:mouse]], 
								 priority: 51,
								 combine: "OR",
								 group: "Protein"
end