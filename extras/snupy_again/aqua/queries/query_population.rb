class QuerySimplePopulation < SimpleQuery
	register_query :population_frequency, 
								 label: "Population frequency",
								 tooltip: "Frequency in population does not exceed this threshold.",
								 default: "0.15",
								 type: :double,
								 organism: [@@ORGANISMS[:human]], 
								 priority: 30,
								 combine: "AND",
								 group: "Basic"
end