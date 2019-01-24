# == Description
# Reduces the query to the results obtained in a given job
# == Attributes
# [name] :job_result
# [label] Queue Result
# [default] ""
# [type] :selection
# [organisms] mouse, human
# [priority] 31
# [combine] OR 
class QueryJobResult < SimpleQuery
	register_query :job_result, 
								 label: "Part of previous Query Result",
								 type: :collection,
								 organism: [@@ORGANISMS[:human], @@ORGANISMS[:mouse]], 
								 priority: 100,
								 combine: "OR"
	register_query :job_result_not, 
								 label: "Not Part of previous Query Result",
								 type: :collection,
								 organism: [@@ORGANISMS[:human], @@ORGANISMS[:mouse]], 
								 priority: 100.1,
								 combine: "OR"
	
end