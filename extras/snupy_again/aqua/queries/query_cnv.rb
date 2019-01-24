# == Description
# Queries for clinical features
class QueryCnv < SimpleQuery
	register_query :cnv_gain_loss, 
								 label: "Gain or Loss of CNV",
								 default: ["strong loss", "loss", "gain", "strong gain"],
								 tooltip: "strong loss: less than one copy, loss: less than 2 copies, gain: more than 2 copies, strong gain: more than 4 copies",
								 type: :select,
								 organism: [@@ORGANISMS[:human], @@ORGANISMS[:mouse]], 
								 priority: 200,
								 combine: "OR",
								 group: "CNV"
	register_query :cnv_percentage_overlap, 
								 label: "Minimum percentate overlap",
								 default: "0.85",
								 type: :double,
								 organism: [@@ORGANISMS[:human], @@ORGANISMS[:mouse]], 
								 priority: 201,
								 combine: "AND",
								 group: "CNV"
	register_query :cnv_bp_overlap, 
								 label: "Minimum overlap in bp",
								 default: "",
								 type: :number,
								 organism: [@@ORGANISMS[:human], @@ORGANISMS[:mouse]], 
								 priority: 202,
								 combine: "AND",
								 group: "CNV"

end