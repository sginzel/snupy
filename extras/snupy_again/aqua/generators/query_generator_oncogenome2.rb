class QueryGeneratorOncogenome2 < QueryGeneratorOncogenome
	config_generator label: "Oncogenome 2 (RLPS)",
					 requires: {},
					 options: {
						 tool:  ["Somatic", "Varscan2", "Mutect"],
						 read_depth: "10",
						 population_frequency: "0.01"
					 }
	def get_tag
		'RLPS'
	end
end