module SnupyAgain
	module StatisticCollector
		class SampleGenderCollector < SnupyAgain::StatisticCollector::Template
			attr_collectable :sample 
			
			def do_collect()
				sample = @object
				stats = {
					id: sample.id,
					nickname: sample.nickname,
					name: sample.name,
					coeff: sample.gender_coefficient,
					description: "The gender coefficient is the ratio between the homozygous/heterozygous ratio on the X chromsome vs average homozygous/heterozygous ratio on the gonosomes. Larger values mean higher degree of homozygous X mutations."
				}
				
				if stats[:coeff].nan? then
					gender_tag = "undecided (empty?)"
				elsif stats[:coeff] <= 0.75 then
					gender_tag = "undecided (female)"
				elsif stats[:coeff] > 0.75 and stats[:coeff] <= 1.25 then
					gender_tag = "female"
				elsif stats[:coeff] > 1.25 and stats[:coeff] <= 1.75 then
					gender_tag = "undecided (male)"
				elsif stats[:coeff] > 1.75 and stats[:coeff] <= 2.25 then
					gender_tag = "male"
				elsif stats[:coeff] > 2.25 then
					gender_tag = "undecided (male)"
				end
				stats[:gender_prediction] = gender_tag
				
				tag = SampleStatistic.new(
					sample_id: sample.id,
					name: "SampleGender",
					resource: self.class.name,
					value: [stats].to_yaml,
					plotstyle: "table"
				)
				tag
			end
		end
	end
end