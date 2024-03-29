class QuerySample < SimpleQuery
	register_query :present_in_any, 
								 label: "Also present in any",
								 default: [], 
								 type: :collection,
								 tooltip: "Retrieved variants should also occur in any of these samples.",
								 organism: [organisms(:human), organisms(:mouse)], 
								 priority: 20.1,
								 group: "Compare to other Samples"
	register_query :present_in_all, 
								 label: "Also present in all",
								 default: [], 
								 type: :collection,
								 tooltip: "Retrieved variants should also occur in all of these samples.",
								 organism: [organisms(:human), organisms(:mouse)], 
								 priority: 20,
								 group: "Compare to other Samples"
								 
	register_query :not_present_in_any, 
								 label: "Not present in",
								 default: [], 
								 type: :collection,
								 tooltip: "Retrieved variants should not occur in these samples.",
								 organism: [organisms(:human), organisms(:mouse)], 
								 priority: 21,
								 group: "Compare to other Samples"
	register_query :not_present_in_any_other, 
								 label: "Not present in any other sample",
								 default: [], 
								 type: :checkbox,
								 tooltip: "Retrieved variants are exclusive to the selected samples.",
								 organism: [organisms(:human), organisms(:mouse)], 
								 priority: 21.1,
								 group: "Compare to other Samples"
								 
	register_query :heterozygous_in_all, 
								 label: "Heterozygous in all",
								 default: [], 
								 type: :collection,
								 tooltip: "Retrieved variants which are also heterozygous in all these samples.",
								 combine: "AND",
								 organism: [organisms(:human), organisms(:mouse)], 
								 priority: 22,
								 group: "Compare to other Samples"
	register_query :heterozygous_in_any, 
								 label: "Heterozygous in any",
								 default: [], 
								 type: :collection,
								 tooltip: "Retrieved variants which are also heterozygous in any of these samples.",
								 combine: "AND",
								 organism: [organisms(:human), organisms(:mouse)], 
								 priority: 22.1,
								 group: "Compare to other Samples"
								 
	register_query :homozygous_in_any, 
								 label: "Homozygous in any",
								 default: [], 
								 type: :collection,
								 tooltip: "Retrieved variants which are homozygous in any of these samples.",
								 combine: "AND",
								 organism: [organisms(:human), organisms(:mouse)], 
								 priority: 23.1,
								 group: "Compare to other Samples"
	register_query :homozygous_in_all, 
								 label: "Homozygous in all",
								 default: [], 
								 type: :collection,
								 tooltip: "Retrieved variants which are homozygous in all of these samples.",
								 combine: "AND",
								 organism: [organisms(:human), organisms(:mouse)], 
								 priority: 23,
								 group: "Compare to other Samples"
								 
	#register_query :compound_heterozygous,
	#							 label: "Compound heterozygous in",
	#							 default: [],
	#							 type: :collection,
	#							 tooltip: "Retrieved variants should be compound heterozygous towards these samples.",
	#							 organism: [organisms(:human), organisms(:mouse)],
	#							 priority: 24
	register_query :baf_difference_gt,
								 label: "BAF difference",
								 default: [], 
								 type: :collection,
								 tooltip: "Absolulte BAF difference is greater than a selected threshold compared to the selected samples. If multiple samples are selected the maximum and minimum baf are compared.",
								 organism: [organisms(:human), organisms(:mouse)], 
								 priority: 25
								 
	register_query :present_in_at_least_sample, 
								 label: "Present in at least X samples",
								 default: "", 
								 type: :number,
								 tooltip: "Retrieved variants which are present in at least X of the selected samples",
								 example: 'ignored if < 1',
								 combine: "AND",
								 organism: [organisms(:human), organisms(:mouse)], 
								 priority: 26,
								 use_query_splicing: true # using params in the filter enables the filters to use all submitted sample ids

	register_query :present_in_at_least_patient, 
								 label: "Present in at least X patients",
								 default: "", 
								 type: :number,
								 tooltip: "Retrieved variants which are present in at least X patients",
								 example: 'ignored if < 1',
								 combine: "AND",
								 organism: [organisms(:human), organisms(:mouse)], 
								 priority: 26.1,
								 use_query_splicing: true # using params in the filter enables the filters to use all submitted sample ids
	
	register_query :query_design, 
								 label: "Advanced query design",
								 default: "", 
								 type: :textarea,
								 tooltip: "Retrieved variants which are present in the defined subset of variants. Combine samples with -, | and &. Add samples with +. Use [gt: \"1/1\", dp: 3] to filter samples by genotype and read depth. Make use of parenthesis () to create groups. E.g. (1&2)+(3|4[gt:\"1/1\"]). Samples in the design need to be selected as part of the query.",
								 example: '(3 & 4) + (5 & 6)',
								 combine: "AND",
								 organism: [organisms(:human), organisms(:mouse)], 
								 priority: 27,
								 group: "Advanced"
	register_query :query_design_not, 
								 label: "Not in advanced query design",
								 default: "", 
								 type: :textarea,
								 tooltip: "Retrieved variants which are present in the defined subset of variants. Combine samples with -, | and &. Add samples with +. Use [gt: \"1/1\", dp: 3] to filter samples by genotype and read depth. Make use of parenthesis () to create groups. E.g. (1&2)+(3|4[gt:\"1/1\"]). Samples in the design need to be selected as part of the query.",
								 example: '4[gt: "1/1"]["dp > 100"] & (5[gt: "0/1"] & 6[gt: ["0/1", "1/2"]])',
								 combine: "AND",
								 organism: [organisms(:human), organisms(:mouse)], 
								 priority: 27.1,
								 group: "Advanced"
	
end