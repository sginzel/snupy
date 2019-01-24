module SnupyAgain
	module StatisticCollector
		class SampleVariationCollector < SnupyAgain::StatisticCollector::Template
			def do_collect()
				sample = @object
				stats = {
					id: sample.id,
					nickname: sample.nickname,
					name: sample.name
				}
				## count total number of variations
				stats["#Total"] = sample.variation_calls.where(filter: "PASS").count(:variation_id, distinct: true)
				stats["# 1/1"] = sample.variation_calls.where(gt: "1/1", filter: "PASS").count(:variation_id, distinct: true)
				stats["# 0/1"] = sample.variation_calls.where(gt: "0/1", filter: "PASS").count(:variation_id, distinct: true)
				stats["# 1/2"] = sample.variation_calls.where(gt: "1/2", filter: "PASS").count(:variation_id, distinct: true)
				## PHASED
				stats["# 1|1"] = sample.variation_calls.where(gt: "1|1", filter: "PASS").count(:variation_id, distinct: true)
				stats["# 0|1"] = sample.variation_calls.where(gt: "0|1", filter: "PASS").count(:variation_id, distinct: true)
				stats["# 1|0"] = sample.variation_calls.where(gt: "1|1", filter: "PASS").count(:variation_id, distinct: true)
				stats["# 1|2"] = sample.variation_calls.where(gt: "1|2", filter: "PASS").count(:variation_id, distinct: true)
				
				## count how many well covered variations we have
				stats["#Total (DP>=20)"] = sample.variation_calls.where(filter: "PASS").where("dp >= 20").count(:variation_id, distinct: true)
				stats["# 1/1 (DP>=20)"] = sample.variation_calls.where(gt: "1/1", filter: "PASS").where("dp >= 20").count(:variation_id, distinct: true)
				stats["# 0/1 (DP>=20)"] = sample.variation_calls.where(gt: "0/1", filter: "PASS").where("dp >= 20").count(:variation_id, distinct: true)
				stats["# 1/2 (DP>=20)"] = sample.variation_calls.where(gt: "1/2", filter: "PASS").where("dp >= 20").count(:variation_id, distinct: true)
				## PHASED
				stats["# 1|1 (DP>=20)"] = sample.variation_calls.where(gt: "1|1", filter: "PASS").where("dp >= 20").count(:variation_id, distinct: true)
				stats["# 0|1 (DP>=20)"] = sample.variation_calls.where(gt: "0|1", filter: "PASS").where("dp >= 20").count(:variation_id, distinct: true)
				stats["# 1|0 (DP>=20)"] = sample.variation_calls.where(gt: "1|0", filter: "PASS").where("dp >= 20").count(:variation_id, distinct: true)
				stats["# 1|2 (DP>=20)"] = sample.variation_calls.where(gt: "1|2", filter: "PASS").where("dp >= 20").count(:variation_id, distinct: true)
				stats["# 2|1 (DP>=20)"] = sample.variation_calls.where(gt: "2|1", filter: "PASS").where("dp >= 20").count(:variation_id, distinct: true)

				## initialize the Hash Map so we can have a static order on the results
				%w(Insertion Deletion A>C A>G A>T C>A C>G C>T G>A G>C G>T T>A T>C T>G).each do |k|
					stats[k] = 0
					stats[k + " (DP>=20)"] = 0
				end

				sample.variation_calls.where(filter: "PASS").includes(:alteration).each do |vc|
					key = sprintf("%s>%s", vc.alteration.ref,vc.alteration.alt)
					if key.size > 3 then
						key = "Deletion" if vc.alteration.ref.size > vc.alteration.alt.size
						key = "Insertion" if vc.alteration.ref.size < vc.alteration.alt.size
					end
					stats[key] = 0 if stats[key].nil?
					stats[key] = stats[key] + 1
					if vc.dp >= 20 then
						stats[key + " (DP>=20)"] = 0 if stats[key + " (DP>=20)"].nil?
						stats[key + " (DP>=20)"] = stats[key + " (DP>=20)"] + 1 
					end
				end
				
				tbl = [stats]
				tag = SampleStatistic.new(
					sample_id: sample.id,
					name: "SampleVariation",
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