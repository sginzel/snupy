# == Description
# A Query to hold all batch filters
class QueryBatch < SimpleQuery
	register_batch_query VariationCall, {
		"id" => :collection,
		"variation_id" => :collection,
		"gt" => :collection,
		"sample_id" => :collection,
		"dp" => :range_gt,
		"cn" => :text,
		"fs" => :range_lt,
		"filter" => :collection,
		"qual" => :range_gt
	}
	
	register_batch_query Sample, {
		"id" => :collection,
		"name" => :collection,
		"nickname" => :collection,
		"entity_group_id" => :collection,
		"entity_id" => :collection,
		"specimen_probe_id" => :collection,
		"vcf_file_id" => :collection,
		"gender" => :text,
		"ignore_filter" => :text,
		"min_read_depth" => :range_gt
	}

end