# == Description
# Queries for variants that lead to potential loss of function
class QueryLossOfFunction < SimpleQuery
	register_query :loss_of_function, 
								 label: "Variant leads to loss of function",
								 default: "0",
								 type: :checkbox,
								 organism: [@@ORGANISMS[:human], @@ORGANISMS[:mouse]], 
								 priority: 50,
								 combine: "OR",
								 group: "Damage Assessment"

	register_query :conservation, 
								 label: "Variant affects conserved region",
								 default: "0",
								 type: :checkbox,
								 organism: [@@ORGANISMS[:human], @@ORGANISMS[:mouse]], 
								 priority: 50.1,
								 combine: "OR",
								 group: "Damage Assessment"
end