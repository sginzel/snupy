class QueryCadd < SimpleQuery # can be ComplexQuery as well.
	register_query :query_cadd,
				   label: "Cadd Score",
				   default: 15, # in case of :collection give a default array. If type is different use another defalt.
				   type: :number, # may be :text, :number, :range, :gt, :lt
				   combine: "OR", # may be AND
				   tooltip: "CADD scores are available for exonic regions & AgilentV5 capture regions +/- 50bp. Recommendations for deleterious CADD scores vary between 10 and 20. Cutoff of 15 was proposed by I. Meyts et al. 2016.",
				   organism: [organisms(:human)], # add other organism if applicable
				   priority: 30.1,
					 group: "Basic"

end