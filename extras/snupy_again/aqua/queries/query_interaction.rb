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
class QueryInteraction < SimpleQuery
	register_query :gene_interaction, 
								 label: "Interacts with",
								 default: "", 
								 type: :delimtext,
								 example: 'RUNX1,TP53',
								 organism: [@@ORGANISMS[:human], @@ORGANISMS[:mouse]], 
								 priority: 30,
								 combine: "AND",
								 group: "Protein"
	register_query :gene_interaction_panel, 
								 label: "Gene interacts with panel",
								 type: :collection,
								 organism: [@@ORGANISMS[:human], @@ORGANISMS[:mouse]], 
								 priority: 31,
								 combine: "OR",
								 group: "Protein"
end