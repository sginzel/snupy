module SnupyAgain
	module StatisticCollector
		class BafCollector < SnupyAgain::StatisticCollector::Template
			
			def do_collect()
				sample = @object
				baf_dist = Hash[(0..100).map{|x| [x.to_f/100, 0]}]
				# we need a read depth of 20 at least to get any meaningful resolution
				sample.variation_calls
				.where(filter: ["PASS", "."], gt: ["0/1", "1/0", "0|1", "1|0", "1|2", "2|1"])
				.where("dp >= ?", 20) 
				.each do |vc|
					refc = vc.ref_reads.to_f
					altc = vc.alt_reads.to_f
					## in this case we have have to handle a heterozygous without reference SNP call
					if refc < 0 or altc < 0 then 
						# No sufficient read depth information for #{sample.name} for #{vc.attributes}
						next
					else
						# k = (altc/(refc + altc)).round(2) # using this will not calculate the frequency of multi-allelic variants correctly
						k = (altc/(vc.dp)).round(2)
					end 
					## sometimes a variation call can have more reference reads than alternative reads (happens at least for mutect calls)
					## this is bad and should be called a failed SNP call
					## in case it actually makes it through we will reject it for BAF calculation
					next if k > 1.0 
					baf_dist[k] = baf_dist[k] + 1 
				end
				tag = SampleStatistic.new(
					sample_id: sample.id,
					name: "BAF",
					resource: self.class.name,
					value: baf_dist.to_yaml,
					plotstyle: "series_wo_points"
				)
				tag
			end

			attr_collectable :sample 
			
		end
	end
end