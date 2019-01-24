class QueryVariationId < SimpleQuery
	register_query :varid, 
								 label: "Variation ID",
								 default: "",
								 type: :delimtext,
								 organism: [@@ORGANISMS[:human], @@ORGANISMS[:mouse]], 
								 priority: 30.1,
								 combine: "OR",
								 group: "Advanced"
	
end