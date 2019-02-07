class QueryPfam < SimpleQuery # can be ComplexQuery as well.
	register_query :query_pfam,
				   label: "Some query",
				   default: ['default_value1'], # in case of :collection give a default array. If type is different use another defalt.
				   type: :collection, # may be :text, :number, :range, :gt, :lt
				   combine: "OR", # may be AND
				   tooltip: "Some tooltip.",
				   organism: [organisms(:human), organisms(:mouse)], # add other organism if applicable
				   priority: 15,
				   group: "Basic",
				   active: false # use this to activate your query once it is ready

end