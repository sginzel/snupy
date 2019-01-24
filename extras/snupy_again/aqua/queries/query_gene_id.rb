# == Description
# Queries for different gene ids
# == Attributes
# [name] :gene_id
# [label] Gene ID
# [default] ""
# [type] :text
# [organisms] mouse, human
# [priority] 100
# [combine] OR 
class QueryGeneId < SimpleQuery
	register_query :gene_id, 
								 label: "Gene ID",
								 default: "", 
								 type: :delimtext,
								 example: 'TP53 (open settings for other ID types)',
								 organism: [@@ORGANISMS[:human], @@ORGANISMS[:mouse]], 
								 priority: 30,
								 combine: "OR",
								 group: "Basic"
	register_query :gene_id_panel, 
								 label: "Gene in panel",
								 type: :collection,
								 organism: [@@ORGANISMS[:human], @@ORGANISMS[:mouse]], 
								 priority: 31,
								 combine: "OR",
								 group: "Basic"
	
end