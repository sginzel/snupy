module SnupyAgain
	module AnnotationSummary
		def summary(variation_ids, organismid)
			variation_ids = [variation_ids] unless variation_ids.is_a?(Array)
			ret = {}
			quantile_estimators = AquaQuantile.where(model_table: self.table_name, organism_id: organismid)
			return {} if quantile_estimators.nil?
			model = quantile_estimators.first.model
			return {} unless model.respond_to?(:summary_categories)
			quantile_estimators = Hash[quantile_estimators.map{|aq| [aq.attribute_column, aq]}]
			
			summary = {}
			weight_sum = Hash.new(0.0)
			model.summary_categories.each do |category, attrs|
				summary[category] = attrs.map{|attr|
					qestimator = quantile_estimators[attr.to_s] || quantile_estimators[attr.to_sym]
					next if qestimator.nil?
					weight_sum[category] += qestimator.weight.to_f
					{
						category: category,
						estimator: qestimator,
						weight: qestimator.weight
					}
				}.reject(&:nil?)
			end
			
			d weight_sum.pretty_inspect.to_s.yellow
			
			self.where(variation_id: variation_ids, organism_id: organismid).each do |rec|
				next unless rec.class.respond_to?(:summary)
				#summary = rec.summary()
				quantiles = {}
				summary.each do |category, estimator_configs|
					quantiles[category] = estimator_configs.map do |estimator_config|
						value = rec[estimator_config[:estimator].attribute_column]
						q = estimator_config[:estimator].estimate_quantile(value)
						w = 0
						if !weight_sum[estimator_config[:category]].nil? and !estimator_config[:weight].nil? then
							w = estimator_config[:weight]/weight_sum[estimator_config[:category]]
						end
						[q, w]
					end
				end
				
				if ret[rec.variation_id].nil?
					ret[rec.variation_id] = quantiles
				else # take max score of each attribute
					ret[rec.variation_id].keys.each do |k|
						ret[rec.variation_id][k] = [[ret[rec.variation_id][k].first, quantiles[k].first].max, quantiles[k].last]
					end
				end
			end
			ret.keys.each do |varid|
				#ret[varid][:median] = ret[varid].values.to_scale.median
				#ret[varid][:mean] = ret[varid].values.to_scale.mean.round(2)
				# ret[varid][:qscore] = ret[varid].values.reject(&:nil?).inject(&:*).round(2)
				qscore = []
				qscorew = []
				ret[varid].keys.each do |category|
					quantiles = ret[varid][category].map(&:first).reject(&:nil?)
					quantiles_weighted = ret[varid][category].reject{|q,w| q.nil? || w.nil?}.map{|q,w| q*w}
					# arr = ret[varid][category].reject(&:nil?)
					if quantiles.size > 0 # aggregate the different quantiles by category -> all conservation scores
						q = quantiles.to_scale.mean
						q_weighted = quantiles_weighted.to_scale.mean
						ret[varid][category] = q.round(2) # mean
						# ret[varid][category.to_s + "_weighted"] = q_weighted.round(2)
						
						qlogit = quantiles.map{|q|
							AquaQuantile.logit(q)
						}.to_scale.mean # this is equivalent to calculating the geometric mean
						qlogit_weighted = quantiles_weighted.map{|q|
							AquaQuantile.logit(q)
						}.to_scale.mean # this is equivalent to calculating the geometric mean
						qscore << qlogit
						qscorew << qlogit_weighted
					else
						ret[varid][category] = nil
					end
				end
				qscore.reject!(&:nil?)
				ret[varid][:qscore] = nil
				if qscore.size > 0
					# ret[varid][:qscore] = qscore.inject(&:*).round(2) # multiplying is bad, because some values might get a 0 quantile
					# ret[varid][:qscore] = qscore.to_scale.mean#.round(2) # mean
					ret[varid][:qscore] =  qscore.to_scale.mean #.round(2) # mean
					#ret[varid][:qscore_weighted] = AquaQuantile.invlogit( qscorew.to_scale.mean )#.round(2) # mean
					ret[varid][:qscore_phred] = AquaQuantile.to_phred(AquaQuantile.invlogit(ret[varid][:qscore])).round(3) #(-10 * Math.log10(1-ret[varid][:qscore])).round(2)
					ret[varid][:qscore] = ret[varid][:qscore].round(3)
					#ret[varid][:qscore_weighted_phred] = (-10 * Math.log10(1-ret[varid][:qscore_weighted])).round(2)
				end
			end
			return nil if ret.size == 0
			ret
		end
	end
end