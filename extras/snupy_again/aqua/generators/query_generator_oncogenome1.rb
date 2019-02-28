class QueryGeneratorOncogenome1 < QueryGeneratorOncogenome
	config_generator label: "Oncogenome 1 (INIT)",
					 requires: {},
					 options: {
						 tool:  ["Somatic", "Varscan2", "Mutect"],
						 read_depth: "10",
						 population_frequency: "0.01"
					 }
	def get_tag
		'INIT'
	end
end
