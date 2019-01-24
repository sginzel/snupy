class FilterAnnovarConservation < SimpleFilter
	create_filter_for QueryLossOfFunction, :conservation,
						name: :annovar_gerp, 
						label: "GERP Score (>=2)",
						filter_method: lambda{|rec| "annovars.gerp_rs >= 2"},
						organism: [organisms(:human)],
						checked: true,
						requires: {
							Annovar => [:gerp_rs]
						},
						tool: AnnovarAnnotation
						
	create_filter_for QueryLossOfFunction, :conservation,
						name: :annovar_phylop_placental, 
						label: "PhyloP Placental (>=1.5)",
						filter_method: lambda{|rec| "annovars.phylop46way_placental >= 1.5"},
						organism: [organisms(:human)],
						checked: true,
						requires: {
							Annovar => [:phylop46way_placental]
						},
						tool: AnnovarAnnotation
	create_filter_for QueryLossOfFunction, :conservation,
						name: :annovar_phylop_placental_hig, 
						label: "PhyloP Placental (>=2)",
						filter_method: lambda{|rec| "annovars.phylop46way_placental >= 2"},
						organism: [organisms(:human)],
						checked: false,
						requires: {
							Annovar => [:phylop46way_placental]
						},
						tool: AnnovarAnnotation
						
	create_filter_for QueryLossOfFunction, :conservation,
						name: :annovar_phylop_vertebrate, 
						label: "PhyloP Placental (>=1.5)",
						filter_method: lambda{|rec| "annovars.phylop100way_vertebrate >= 1.5"},
						organism: [organisms(:human)],
						checked: true,
						requires: {
							Annovar => [:phylop100way_vertebrate]
						},
						tool: AnnovarAnnotation
	create_filter_for QueryLossOfFunction, :conservation,
						name: :annovar_phylop_vertebrate_hig, 
						label: "PhyloP Placental (>=2)",
						filter_method: lambda{|rec| "annovars.phylop100way_vertebrate >= 2"},
						organism: [organisms(:human)],
						checked: false,
						requires: {
							Annovar => [:phylop100way_vertebrate]
						},
						tool: AnnovarAnnotation
	
	create_filter_for QueryLossOfFunction, :conservation,
						name: :annovar_siphy,
						label: "Siphy Log-Odds (>=3)",
						filter_method: lambda{|rec| "annovars.siphy_29way_logOdds >= 3"},
						organism: [organisms(:human)],
						checked: true,
						requires: {
							Annovar => [:siphy_29way_logOdds]
						},
						tool: AnnovarAnnotation
	
end