class FilterAnnovarPopulation < SimpleFilter
	create_filter_for QuerySimplePopulation, :population_frequency,
						name: :annovar_onekg, 
						label: "1000 Genomes Oct. 2014",
						filter_method: lambda{|val| "(annovars.genome_2014oct IS NULL) OR (annovars.genome_2014oct <= #{val.to_f})" },
						organism: [organisms(:human)],
						checked: false, 
						requires: {
							Annovar => [:genome_2014oct]
						},
						tool: AnnovarAnnotation
						
	create_filter_for QuerySimplePopulation, :population_frequency,
						name: :annovar_cd69, 
						label: "Complete Genome 69",
						filter_method: lambda{|val| "(annovars.cg69 IS NULL) OR (annovars.cg69 <= #{val.to_f})" },
						organism: [organisms(:human)],
						checked: false, 
						requires: {
							Annovar => [:cg69]
						},
						tool: AnnovarAnnotation
	
		create_filter_for QuerySimplePopulation, :population_frequency,
						name: :annovar_esp6500, 
						label: "ESP 6500",
						filter_method: lambda{|val| "(annovars.esp6500siv2_all IS NULL) OR (annovars.esp6500siv2_all <= #{val.to_f})" },
						organism: [organisms(:human)],
						checked: false, 
						requires: {
							Annovar => [:esp6500siv2_all]
						},
						tool: AnnovarAnnotation
		
		create_filter_for QuerySimplePopulation, :population_frequency,
						name: :annovar_exac, 
						label: "ExAC all",
						filter_method: lambda{|val| "(annovars.exac_all IS NULL) OR (annovars.exac_all <= #{val.to_f})" },
						organism: [organisms(:human)],
						checked: false, 
						requires: {
							Annovar => [:exac_all]
						},
						tool: AnnovarAnnotation

end