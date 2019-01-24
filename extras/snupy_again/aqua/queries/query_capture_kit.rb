class QueryCaptureKit < SimpleQuery # can be ComplexQuery as well.
	register_query :query_capture_kit,
				   label: "Variant hits this target region",
				   default: [], # in case of :collection give a default array. If type is different use another defalt.
				   type: :collection, # may be :text, :number, :range, :gt, :lt
				   combine: "OR", # may be AND
				   tooltip: "Looks for variants within a target region. Select different filter for thresholds.",
				   organism: [organisms(:human), organisms(:mouse)], # add other organism if applicable
				   priority: 11.11,
						group: "Basic"

	register_query :query_capture_kit_on_target,
								 label: "Variant hits any target region",
								 default: false, # in case of :collection give a default array. If type is different use another defalt.
								 type: :checkbox, # may be :text, :number, :range, :gt, :lt
								 combine: "OR", # may be AND
								 tooltip: "Any hit in any registered target region (faster).",
								 organism: [organisms(:human), organisms(:mouse)], # add other organism if applicable
								 priority: 11.111,
								 group: "Other"

end