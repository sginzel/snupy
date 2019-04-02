# == Description
# Queries for different variation call statistics
# == Attributes
# [name] :read_depth
# [label] Read depth
# [default] "10"
# [type] :numeric
# [organisms] mouse, human
# [priority] 100
# [combine] OR 
class QueryVariationCall < SimpleQuery
	register_query :read_depth, 
								 label: "Read depth",
								 default: [0, 300, 13],
								 type: :range_gt,
								 tooltip: "Read depth exceeds...",
								 organism: [organisms(:human), organisms(:mouse)], 
								 priority: 10,
								 group: "Basic"
	
	register_query :allele_frequency,
	               label: "Allele Frequency in %",
	               default: [0, 100, 0, 100],
	               type: :range,
	               tooltip: "Frequency of alternative allele is between...",
	               organism: [organisms(:human), organisms(:mouse)],
	               priority: 10,
	               group: "Basic"
	
	register_query :genotype, 
								 label: "Genotype",
								 type: :collection,
								 tooltip: "Genotype",
								 organism: [organisms(:human), organisms(:mouse)], 
								 priority: 11,
								 group: "Basic"
	
	register_query :genotype_quality, 
								 label: "Genotype quality",
								 type: :number,
								 tooltip: "Genotype quality",
								 example: "90",
								 organism: [organisms(:human), organisms(:mouse)], 
								 priority: 11.1
	
	register_query :varqual, 
								 label: "Variation Quality",
								 default: "30", 
								 type: :numeric,	
								 organism: [organisms(:human), organisms(:mouse)], 
								 priority: 10.1
	
	register_query :region, 
								 label: "Region",
								 default: "", 
								 type: :delimtext,	
 								 example: 'X, Y:12345, 22:10-100',
								 organism: [organisms(:human), organisms(:mouse)], 
								 priority: 11.2
	
end