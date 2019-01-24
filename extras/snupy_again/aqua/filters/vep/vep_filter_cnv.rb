class VepFilterCnv < SimpleFilter
	create_filter_for QueryCnv, :cnv_percentage_overlap,
						name: :vep_percent_overlap, 
						label: "Relative overlap with Ensembl Features (VEP)",
						filter_method: lambda{|value| "#{Vep::Ensembl.colname(:percentage_overlap)} >= #{value}"},
						organism: [organisms(:human), organisms(:mouse)],
						checked: false,
						requires: {
							Vep::Ensembl => [:percentage_overlap]
						},
						tool: VepAnnotation
	create_filter_for QueryCnv, :cnv_bp_overlap,
						name: :vep_bp_overlap, 
						label: "Absolute overlap with Ensembl Features (VEP)",
						filter_method: lambda{|value| "#{Vep::Ensembl.colname(:bp_overlap)} >= #{value}"},
						organism: [organisms(:human), organisms(:mouse)],
						checked: false,
						requires: {
							Vep::Ensembl => [:bp_overlap]
						},
						tool: VepAnnotation
	create_filter_for QueryCnv, :cnv_percentage_overlap,
						name: :vep_percent_overlap, 
						label: "Relative overlap with RefSeq Features (VEP)",
						filter_method: lambda{|value| "#{Vep::RefSeq.colname(:percentage_overlap)} >= #{value}"},
						organism: [organisms(:human), organisms(:mouse)],
						checked: false,
						requires: {
							Vep::RefSeq => [:percentage_overlap]
						},
						tool: VepAnnotation
	create_filter_for QueryCnv, :cnv_bp_overlap,
						name: :vep_bp_overlap, 
						label: "Absolute overlap with RefSeq Features (VEP)",
						filter_method: lambda{|value| "#{Vep::RefSeq.colname(:bp_overlap)} >= #{value}"},
						organism: [organisms(:human), organisms(:mouse)],
						checked: false,
						requires: {
							Vep::RefSeq => [:bp_overlap]
						},
						tool: VepAnnotation
end