class FilterVariationCall < SimpleFilter
	create_filter_for QueryVariationCall, :read_depth,
					  name: :vcdp,
					  label: "Read depth of variant.",
						filter_method: :dp,
						organism: [organisms(:human), organisms(:mouse)], 
						requires: {VariationCall => [:dp]},
						checked: true,
						tool: Annotation
						
	create_filter_for QueryVariationCall, :genotype,
					  name: :vcgt,
					  label: "Predicted genotype",
						filter_method: :gt,
						collection_method: :list_genotypes,
						organism: [organisms(:human), organisms(:mouse)], 
						requires: {VariationCall => [:gt]},
						tool: Annotation

	create_filter_for QueryVariationCall, :genotype_quality,
					  name: :vcgq,
					  label: "Genotype Quality",
						filter_method: :gq,
						organism: [organisms(:human), organisms(:mouse)], 
						requires: {VariationCall => [:gq]},
						checked: false,
						tool: Annotation

	create_filter_for QueryVariationCall, :varqual,
					  name: :vcqual,
					  label: "Variation call quality",
						filter_method: :qual,
						checked: false,
						organism: [organisms(:human), organisms(:mouse)], 
						requires: {VariationCall => [:qual]},
						tool: Annotation
		
		create_filter_for QueryVariationCall, :region,
					  name: :vcregion,
					  label: "Exact region, no overlaps",
						filter_method: :region,
						checked: true,
						organism: [organisms(:human), organisms(:mouse)], 
						# requires: {Region => [:name, :start, :stop]},
						requires: {Variation => {Region => [:name, :start, :stop]}},
						tool: Annotation

		create_filter_for QueryCnv, :cnv_gain_loss,
					  name: :vccnv_gain_loss,
					  label: "Gain Or Loss Filter",
						filter_method: lambda{|val|
							if (val == "'loss'") 
								"variation_calls.cn < 2"
							elsif (val == "'strong loss'")
								"variation_calls.cn < 1"
							elsif (val == "'strong gain'")
								"variation_calls.cn > 4"
							else
								"variation_calls.cn > 2"
							end
						},
						checked: false,
						organism: [organisms(:human), organisms(:mouse)], 
						requires: {
							VariationCall => [:cn]
						},
						tool: Annotation
		
	## create as SQL condition  
	def dp(value)
		"variation_calls.dp >= #{value}"
	end
	
	def gt(value)
		"variation_calls.gt IN (#{value.join(", ")})"
	end
	
	def gq(value)
		"variation_calls.gq >= #{value}"
	end
	
	
	def qual(value)
		"variation_calls.qual >= #{value}"
	end
	
	def region(value)
		value.map!{|x| x.gsub(/^['"]/, "").gsub(/['"]$/, "")}
		conditions = []
		value.each do |r|
			chr, anfang, ende = r.split(/[:-]/)
			# anfang = 0 if anfang.nil?
			# ende = (anfang==0)?9999999999:anfang if ende.nil?
			next if chr.nil?
			cond = ""
			if (!anfang.nil? and !ende.nil?) then
				cond = "(regions.name = '#{chr}' AND regions.start >= #{anfang} AND regions.stop <= #{ende})"
			elsif (!anfang.nil? and ende.nil?)
				cond = "(regions.name = '#{chr}' AND regions.start = #{anfang})"
			elsif (anfang.nil? and ende.nil?)
				cond = "(regions.name = '#{chr}')"
			end
			conditions << cond if cond.length > 0
		end
		return nil if conditions.size == 0
		conditions.join(" OR ")
	end
	
	def list_genotypes(params)
		VariationCall.select(:gt).uniq.pluck(:gt).sort.map{|rec|
			{
				id: rec,
				"Genotype" => rec
			}
		}
	end
	
end