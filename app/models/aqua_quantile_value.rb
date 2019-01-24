class AquaQuantileValue < ActiveRecord::Base
	belongs_to :aqua_quantile
	attr_accessible :aqua_quantile_id, :quantile, :value
	
	def self.build_set(aqua_quantile, estimator = aqua_quantile.estimator)
		quantiles = AquaQuantile.invariants().map(&:quantile)
		#quantiles << 0.99
		if aqua_quantile.aqua_quantile_values.size == 0 then
			quantiles.sort.map do |q|
				estimate = nil
				if !estimator.nil? then
					estimate = estimator.query(q)
					estimate = estimate.round(5) unless estimate.nil?
				end
				create(aqua_quantile_id: aqua_quantile.id,
				       quantile:         q.round(3),
				       value:            estimate
				)
			end
		end
		aqua_quantile.aqua_quantile_values
	end
	
	def <=>(othraqv)
		self.quantile.to_f <=> othraqv.quantile.to_f
	end
	
	private_class_method :new
	private_class_method :create
end
