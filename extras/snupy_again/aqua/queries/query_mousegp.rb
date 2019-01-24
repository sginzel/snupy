class QueryMousegp < SimpleQuery # can be ComplexQuery as well.
	register_query :query_mousegp,
				   label: "Some query",
				   default: ['default_value1'], # in case of :collection give a default array. If type is different use another defalt.
				   type: :collection, # may be :text, :number, :range, :gt, :lt
				   combine: "OR", # may be AND
				   tooltip: "Some tooltip.",
				   organism: [organisms(:mouse)], # add other organism if applicable
				   priority: 15,
	               active: false,
	               group: "Basic"

end