class VepFilterConsequence < SimpleFilter
	create_filter_for QueryConsequence, :consequence,
						name: :consequence, 
						label: "Consequence",
						filter_method: lambda{|value| "#{Vep::Ensembl.colname(:consequence)} IN (#{value.join(",")})"},
						collection_method: :find_consequences,
						organism: [organisms(:human), organisms(:mouse)],
						checked: false,
						requires: {
							Vep::Ensembl => [:consequence]
						},
						tool: VepAnnotation
	create_filter_for QueryConsequence, :consequence,
						name: :consequence_refseq, 
						label: "Consequence RefSeq",
						filter_method: lambda{|value| "#{Vep::RefSeq.colname(:consequence)} IN (#{value.join(",")})"},
						collection_method: :find_consequences,
						organism: [organisms(:human), organisms(:mouse)],
						checked: false,
						requires: {
							Vep::RefSeq => [:consequence]
						},
						tool: VepAnnotation
	create_filter_for QueryConsequence, :consequence,
						name: :consequence_severe, 
						label: "Most severe consequence",
						filter_method: lambda{|value| "#{Vep::Ensembl.colname(:most_severe_consequence)} IN (#{value.join(",")}) AND #{Vep::Ensembl.colname(:most_severe_consequence)} = #{Vep::Ensembl.colname(:consequence)}"},
						collection_method: :find_consequences,
						organism: [organisms(:human), organisms(:mouse)],
						checked: true,
						requires: {
							Vep::Ensembl => [:most_severe_consequence, :consequence]
						},
						tool: VepAnnotation
	create_filter_for QueryConsequence, :consequence,
						name: :consequence_severe_refseq, 
						label: "Most severe consequence (RefSeq)",
						filter_method: lambda{|value| "#{Vep::RefSeq.colname(:most_severe_consequence)} IN (#{value.join(",")}) AND #{Vep::RefSeq.colname(:most_severe_consequence)} = #{Vep::RefSeq.colname(:consequence)}"},
						collection_method: :find_consequences,
						organism: [organisms(:human), organisms(:mouse)],
						checked: false,
						requires: {
							Vep::RefSeq => [:most_severe_consequence, :consequence]
						},
						tool: VepAnnotation
	create_filter_for QueryConsequence, :consequence,
						name: :consequence_severe_cnv, 
						label: "CNV consequence (Ensembl)",
						filter_method: lambda{ |value|
							"#{Vep::Ensembl.colname(:consequence)} = 'copy_number_variation'"
							},
						collection_method: :find_consequences,
						organism: [organisms(:human), organisms(:mouse)],
						checked: false,
						requires: {
							Vep::Ensembl => [:most_severe_consequence, :consequence]
						},
						tool: VepAnnotation
## AMino Acid exchanges
	def self.amino_acid_gain_loss(from_aas, loss = true, gain = true, to_aas = ["%"])
		cname = Vep::Ensembl.colname(:amino_acids)
		return nil unless loss || gain
		from_aas.map{|aa|
			ret = []
			ret << to_aas.map{|toaa| "#{cname} LIKE '#{aa}/#{toaa}'"}.join(" OR ") if loss
			ret << to_aas.map{|toaa| "#{cname} LIKE '#{toaa}/#{aa}'"}.join(" OR ") if gain
			"(#{ret.join(" OR ")})"
		}.join(" OR ")
	end
	create_filter_for QueryAminoAcidExchanges, :amino_acid,
						name: :amino_acid, 
						label: "Amino Acid Exchange",
						filter_method: :find_amino_acid,
						collection_method: :list_amino_acids,
						organism: [organisms(:human), organisms(:mouse)],
						checked: true,
						requires: {
							Vep::Ensembl => [:amino_acids]
						},
						tool: VepAnnotation
	create_filter_for QueryAminoAcidExchanges, :impactful_amino_acid_exchanges,
						name: :post_translational, 
						label: "Post translational (C|K)>?",
						filter_method: lambda {|vals| 
							amino_acid_gain_loss([:C, :K], true, false)
						},
						organism: [organisms(:human), organisms(:mouse)],
						checked: false,
						requires: {
							Vep::Ensembl => [:amino_acids]
						},
						tool: VepAnnotation
	create_filter_for QueryAminoAcidExchanges, :impactful_amino_acid_exchanges,
						name: :phosphate_acceptor_loss, 
						label: "Phosphate acceptor loss (S|T|Y)>?",
						filter_method: lambda {|vals|
							amino_acid_gain_loss([:S, :T, :Y], true, false)
						},
						organism: [organisms(:human), organisms(:mouse)],
						checked: false,
						requires: {
							Vep::Ensembl => [:amino_acids]
						},
						tool: VepAnnotation
	create_filter_for QueryAminoAcidExchanges, :impactful_amino_acid_exchanges,
						name: :steric_effects, 
						label: "Steric effects (G|A)<>P",
						filter_method: lambda {|vals|
							amino_acid_gain_loss([:G, :A], true, true, [:P])
						},
						organism: [organisms(:human), organisms(:mouse)],
						checked: false,
						requires: {
							Vep::Ensembl => [:amino_acids]
						},
						tool: VepAnnotation
		## register filter by property
	{
		small_to_larger:      ["Small to larger", Vep.AA_GROUPS[:small]],
		tiny_to_larger:       ["Tiny to larger", Vep.AA_GROUPS[:tiny]],
		aromatic_to_other:    ["Aromatic to other", Vep.AA_GROUPS[:aromatic]],
		hydrophobic_to_other: ["Hydrophobic to other", Vep.AA_GROUPS[:hydrophobic]],
		polar_to_other:       ["Polar to other", Vep.AA_GROUPS[:polar]],
		aliphatic_to_other:   ["Aliphatic to other", Vep.AA_GROUPS[:aliphatic]],
		charged_to_other:     ["Charged to other", Vep.AA_GROUPS[:charged]],
		positive_to_negative: ["Positive to negative", Vep.AA_GROUPS[:positive], Vep.AA_GROUPS[:negative]],
		negative_to_positive: ["Negative to positive", Vep.AA_GROUPS[:negative], Vep.AA_GROUPS[:positive]]
	}.each do |name, conf|
		if (conf[2].nil?)
			othr_aas = Vep.AA_GROUPS[:all] - conf[1]
		else
			othr_aas = conf[2]
		end
		create_filter_for QueryAminoAcidExchanges, :impactful_amino_acid_exchanges,
					name: name, 
					label: "#{conf[0]} (PMID: 8143162)",
					filter_method: lambda {|vals|
						amino_acid_gain_loss(conf[1], true, true, othr_aas)
					},
					organism: [organisms(:human), organisms(:mouse)],
					checked: false,
					requires: {
						Vep::Ensembl => [:amino_acids]
					},
					tool: VepAnnotation
	end
		
		
	def find_amino_acid(values)
		"#{Vep::Ensembl.colname(:amino_acids)} IN (#{values.map{|x| x.gsub("_", "/")}.join(",")})"
	end
	
	def find_consequences(params)
		ret = Vep.select(:consequence).uniq.pluck(:consequence).sort.map{|c|
			{
				id: c,
				label: c
			}
		}
		ret
	end
	
	def list_amino_acids(params)
		Vep.AMINO_ACIDS.map{|code, name|
			Vep.AMINO_ACIDS.map{|tocode, toname|
				{
					id: "#{code}_#{tocode}",
					from: "#{code} (#{name})",
					to: "#{tocode} (#{toname})"
				}
			}
		}.flatten
	end
	
end