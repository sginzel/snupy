module SnupyAgain
	module StatisticCollector
		class SampleVariationQualityCollector < SnupyAgain::StatisticCollector::Template
			
			def do_collect()
				sample = @object
				stats = {
					id: sample.id,
					nickname: sample.nickname,
					name: sample.name
				}
				## count total number of variations
				stats["#Avg. DP"] = sample.variation_calls.average(:dp).to_f.round(3)
				stats["#Avg. QUAL"] = sample.variation_calls.average(:qual).to_f.round(3)
				stats["#Avg. GQ"] = sample.variation_calls.average(:gq).to_f.round(3)
				stats["#Avg. REF READS"] = sample.variation_calls.average(:ref_reads).to_f.round(3)
				stats["#Avg. ALT READS"] = sample.variation_calls.average(:alt_reads).to_f.round(3)
				sample.variation_calls.joins(:region).group("regions.name").average(:dp).each do |chr, dp|
					stats["#Avg. DP chr#{chr}"] = dp.to_f.round(3)
				end
				sample.variation_calls.joins(:region).group("regions.name").count(:variation_id).each do |chr, numvar|
					stats["#Variants chr#{chr}"] = numvar.to_i
				end
				
				tbl = [stats]
				tag = SampleStatistic.new(
					sample_id: sample.id,
					name: "SampleVariationQuality",
					resource: self.class.name,
					value: tbl.to_yaml,
					plotstyle: "table"
				)
				tag
			end

			attr_collectable :sample 
			
		end
	end
end