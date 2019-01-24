class AquaQuantile < ActiveRecord::Base
	
	include SnupyAgain::Utils
	
	has_many :aqua_quantile_values, dependent: :destroy
	
	after_save :update_quantile_values
	
	attr_accessible :attribute_column, :direction, :estimator,
	                :last_variation_id, :model, :model_table, :organism_id

	def self.get_by_model(model)
		AquaQuantile.where(model_table: model.table_name)
	end
	
	def self.get_by_model_and_attribute(model, attribute_name)
		AquaQuantile.get_by_model(model).where(attribute_column: attribute_name)
	end
	
	def self.get_by_model_and_attribute_and_organism(model, attribute_name, organism)
		AquaQuantile.get_by_model(model).where(attribute_column: attribute_name, organism_id: organism).first
	end
	
	
	def self.find_existing(model, attribute_column, direction, organism)
		#AquaQuantile.find_by_model_table_attribute_column_direction_organism_id(model, attribute_column, direction, organism)
		where(model_table: model.table_name,
             attribute_column: attribute_column,
             direction: direction,
             organism_id: organism).first
	end
	
	def self.get_for(model, attribute_column, direction, organism)
		aq = find_existing(model, attribute_column, direction, organism)
		aq ||= create(model: model,
		              model_table: model.table_name,
		              attribute_column: attribute_column,
		              direction: direction,
		              organism_id: organism,
		              last_variation_id: 0,
		              estimator: nil
		              )
		aq
	end
	
	def self.invariants(epsilon = 0.01)
		epsilon = 0.01
		(1..100).map {|i|
			(i.to_f * 0.01).round(3)
		}.map{|q|
			Quantile::Quantile.new(q, epsilon)
		}
	end
	
	def invariants()
		if read_attribute(:estimator).nil? then
			AquaQuantile.invariants
		else
			self.estimator.invariants
		end
	end
	
	def estimator
		@_estimator_cache = nil unless defined?(@_estimator_cache)
		data = read_attribute(:estimator)
		begin
			@_estimator_cache = Marshal.load( unzip(data) )
		rescue
		end
		if @_estimator_cache.nil? then
			invariants = AquaQuantile.invariants()
			# self.estimator = Quantile::Estimator.new(Quantile::Quantile.new(0.5, 0.05), Quantile::Quantile.new(0.90, 0.01), Quantile::Quantile.new(0.99, 0.001))
			self.estimator = Quantile::Estimator.new(*invariants)
			@_estimator_cache = self.estimator
			# return self.estimator
		end
		@_estimator_cache
	end
	
	# write the status of the object. This method also checks if the status to be set is valid.
	def estimator= (value)
		raise ArgumentError.new("value is not an Estimator") unless value.is_a?(Quantile::Estimator) or value.nil?
		dumped = Marshal.dump(value)
		write_attribute(:estimator, zip(dumped) )
	end
	
	def model
		data = read_attribute(:model)
		begin
			ret = YAML.load( data )
		end
		ret
	end
	
	# write the status of the object. This method also checks if the status to be set is valid.
	def model= (mdl)
		raise ArgumentError.new("not a valid model") unless mdl.attribute_names.include?("variation_id") && mdl.attribute_names.include?("organism_id")
		dumped = YAML.dump(mdl)
		write_attribute(:model, dumped )
	end

	# estimates the quantile of the given value
	def estimate_quantile(value)
		return nil if value.nil?
		return value.map{|val| esitmate(val)} if value.is_a?(Array)
		# this executes a lof of queries, we dont need
		# Plus can do a bit better, when we interpolate between the two values
		# aqua_quantile_values.where("aqua_quantile_values.value <= #{value}").maximum(:quantile).to_f
		
		# find the value pair where the value is just between the two
		arr = aqua_quantile_values.sort
		quantile_estimate = nil
		(1..(arr.length-1)).each do |i|
			valbefore = arr[i-1]
			val       = arr[i]
			break if valbefore.value.nil? || valbefore.quantile.nil?
			# this can happen when the value is smaller than the smalles observed one
			if valbefore.value >= value then
				quantile_estimate = valbefore.quantile
			elsif val.value < value and i == arr.length-1 then
				quantile_estimate = val.quantile
			end
			
			# found the pair that matches
			if valbefore.value < value and val.value >= value then
				# now let us do a linear approximation
				frac = (value - valbefore.value) / (val.value - valbefore.value)
				quantile_estimate = valbefore.quantile + (val.quantile - valbefore.quantile)*frac
			end
			if direction < 0 and !quantile_estimate.nil? then
				quantile_estimate = 1-quantile_estimate
			end
			break unless quantile_estimate.nil?
		end
		# quantiles cant be 0, because we have observed that given value.
		# The only explaination is that the value falls in a quantile that we haven't seen after N number of observations.
		# Thus the quantile should be 1/N+1
		quantile_estimate = (1.0/(self.estimator.observations + 1)) if quantile_estimate.nil? or quantile_estimate == 0
		quantile_estimate
	end
	
	# log-odss transform
	def logit(value)
		self.class.logodds(estimate_quantile value)
	end
	
	def self.logit(q)
		return nil if q.nil?
		q = 1.0 - 10**-6 if q >= 1.0
		Math.log(q/(1.0-q))
	end
	
	def self.invlogit(l)
		return nil if l.nil?
		Math.exp(l)/(1.0+Math.exp(l))
	end
	
	def self.geom_mean(arr)
		arr = arr.reject(&:nil?)
		return nil if arr.size == 0
		(arr.inject(&:*)**(1.0/arr.size)) # geometric mean
	end
	
	def self.to_phred(f)
		f = f - 10**-4 if f > 0
		(-10 * Math.log10(1-f))
	end
	
	# TODO calculate the weights
	# Returns nil if no quantile values are there
	def weight
		if @_weight.nil? || estimator_changed? then
			aqv = aqua_quantile_values
			n = aqv.length
			# for each quantile, we get the value range
			# this quantile is covering
			# You can think it as finding
			#   P(x=p)
			# from
			#   P( x <= p ) - P(x_-1 <= p)
			p = (1...n).map{ |i|
				next if aqv[i].value.nil?
				x = ((aqv[i].value)-aqv[i-1].value)
				x = 10**-8 if x <= 0
				x
			}.reject(&:nil?)
			return nil if p.size == 0
			
			# now scale it to 1.0
			s = p.inject(&:+)
			p = p.map{|x| x/s}
			
			# create shannon index from the resulting probabilities
			h = p.map{|x|
				x*Math.log(x)
			}.inject(&:+)
			@_weight = h * -1
		end
		@_weight
	end
	
	# generates the weighted average of the supplied quantiles
	# Interestin summary https://stats.stackexchange.com/questions/155817/combining-probabilities-information-from-different-sources
	# Possibly use logit transformation + geometric mean
	def self.combine(values, aqua_quantiles)
	
	end
	
	def list_quantiles
		Hash[aqua_quantile_values.sort.map{|aqv|
			[aqv.quantile, aqv.value]
		}]
	end
	
	def order_colors(colors = ["palegreen", "salmon"])
		if direction < 1 then
			colors.reverse
		else
			colors
		end
	end
	
	def update_estimates(stop_after = 1000000)
		raise "Model Table name has changed" if model.table_name != model_table
		updated_estimator = self.estimator
		
		## find values that have not yet been put into the estimation
		cnt = 0
		max_tries = 100
		batch_size = 10000
		cnt_tries = 0
		puts "Updating #{model_table}.#{attribute_column}(#{organism_id})\n".blue if Rails.env == "development"
		new_last_var = self.last_variation_id
		find_unprocessed_values(batch_size) do |observations, block_new_lastvar|
			cnt += observations.length
			observations.each do |obs|
				next if obs.nil?
				# updated_estimator.observe(obs**direction)
				updated_estimator.observe(obs)
			end
			# reset try_counter when we found observations
			if observations.length == 0 then
				cnt_tries += 1
			else
				cnt_tries = 0
			end
			new_last_var = block_new_lastvar
			print("#{cnt}\r".blue) if Rails.env == "development"
			if cnt_tries >= max_tries
				puts "[update_estimates(#{self.model_table}.#{self.attribute_column} (org: #{self.organism_id})] No new observations found after #{max_tries*batch_size} variants. Aborting at varid #{new_last_var}".yellow
				break
			end
			if cnt >= stop_after
				cnt_tries = 0
				break
			end
		end
		self.last_variation_id = new_last_var
		if cnt > 0
			puts ("#{cnt}.. DONE. Flushing and storing estimator".blue) if Rails.env == "development"
			updated_estimator.send(:flush)
			self.estimator = updated_estimator
			puts "Updated #{cnt} observations for #{model_table}.#{attribute_column}(#{organism_id})".blue if Rails.env == "development"
		end
		self.save
	end
	
	def update_quantile_values()
		if estimator_changed? then
			self.reload
			print "Updating quantile values...".blue if Rails.env == "development"
			quantestimator = self.estimator
			qvalues = aqua_quantile_values
			qvalues = AquaQuantileValue.build_set(self) if qvalues.size == 0
			qvalues.each do |qval|
				val = quantestimator.query(qval.quantile)
				if !val.nil? then
					qval.update_attribute(:value, val)
				end
			end
			puts "DONE...".green if Rails.env == "development"
		else
			puts "Estimator didnt change, no update...".green if Rails.env == "development"
		end
	end
	
	def find_unprocessed_values(batch_size = 10000, &block)
		current_varid = self.last_variation_id || 0
		max_varid = model.where(organism_id: organism_id).maximum(:variation_id)
		return 0 if max_varid.nil?
		while current_varid <= max_varid
			# this makes sure we have the correct last variation id
			next_block = [max_varid, current_varid + batch_size].min
			yield model.where(organism_id: organism_id)
				.where("variation_id > #{current_varid} AND variation_id <= #{next_block}")
				.where("#{attribute_column} IS NOT NULL")
				.select(attribute_column)
				.group(:variation_id).pluck(attribute_column), next_block
			current_varid = next_block
		end
		max_varid
	end
	
	def to_s
		puts <<EOS
#{model_table}.#{attribute_column}(#{last_variation_id}) (Organism: #{organism_id}) (Obs:#{estimator.observations})
#{aqua_quantile_values.map{|aqv| sprintf("%02d%%\t%.4f",aqv.quantile.round(3)*100, aqv.value.to_f.round(4))}.join("\n")}
EOS
	end
	
	private_class_method :new
	private_class_method :create
	
end
