module SimpleStatisticHelper
	def get_entropy(arr, target_sum = nil)
		if (target_sum.nil?) then
			target_sum = arr.to_a.to_scale.sum.round(3).to_f
		end
		entropy = -1.0 * arr.map{|x|
			p = (x.to_f/target_sum)
			(p > 0)?(Math.log2(p)*p):0
		}.sum.round(4).to_f
		entropy = 0 if entropy.to_s == "-0.0" # make sure we dont get weird -0 entropies
		entropy
	end
end