class QueryCompoundHeterozygous < ComplexQuery
	
	register_query :compound_heterozygous,
	               label: "Compound heterozygous in (strict)",
	               default: [],
	               type: :collection,
	               tooltip: "Retrieved variants should be compound heterozygous towards these samples.",
	               organism: [organisms(:human), organisms(:mouse)],
	               priority: 23.3, # make sure this is executed last
	               group: "Compare to other Samples"
end