class FilterBatch < SimpleFilter
	create_batch_filter( VariationCall, %w(id variation_id gt id dp cn fs filter qual))
	create_batch_filter( Sample, %w(id name nickname entity_group_id entity_id specimen_probe_id vcf_file_id gender ignorefilter min_read_depth))
end