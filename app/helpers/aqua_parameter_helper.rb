module AquaParameterHelper
	def _build_query(params)
		opts = _parse_keys(params)
		query = _parse_query_keys(opts)
		agg = _parse_aggregation_keys(opts)
		result = {}
		result.merge!(query) if query.is_a?(Hash)
		result.merge!(agg) if agg.is_a?(Hash)
		result
	end
	
	def _parse_keys(params)
		opts = params.dup
		# check if query names were submitted
		if !(opts[:queries] || opts[:query]).nil? then
			qparams = Aqua.parse_params(opts)
			queries = qparams[:queries]
			# remove queries without filter
			queries = queries.map{|klass, klassqueries| klassqueries.values}
				          .flatten.select{|q| q.filters.size > 0}
			opts[:qkey] = Hash[queries.map{|q|
				[
					q.qkey,
					{value: q.value, combine: q.combine}
				]
			}]
			opts[:fkey] = queries.map{|q| q.filters.map{|f| f.fkey}}.flatten
		end
		# check if aggregations were submitted
		if !(opts[:aggregations] || opts[:aggregation]).nil? then
			qparams = Aqua.parse_params(opts)
			aggregations = qparams[:aggregations]
			opts[:akey] = aggregations.values.flatten.map{|a| a.akey}
		end
		opts
	end
	
	def _parse_query_keys(params)
		queries = {}
		qkeys = (params[:qkey] || params[:qkeys]) || []
		fkeys = (params[:fkey] || params[:fkeys]) || []
		qkeys = qkeys.first if qkeys.is_a?(Array)
		return {query: []} if qkeys.nil? || qkeys.size == 0
		return {query: []} if fkeys.nil? || fkeys.size == 0
		
		qkeys.each do |qkey, qconf|
			qklass, qname = qkey.split(":",2)
			qklass = Aqua._get_klass(qklass.camelcase, Query)
			if qklass.nil? then
				return_status(status = 400, text = "#{qkey} is not a valid query.")
				return true
			end
			queries[qklass.name.underscore] = {} if queries[qklass.name.underscore].nil?
			
			if qconf.is_a?(Hash) then
				value = qconf[:value] || qklass.configuration_for(qname)[:default]
				combine = qconf[:combine] || qklass.configuration_for(qname)[:combine]
			else
				value = qconf
				combine = qklass.configuration_for(qname)[:combine]
			end
			
			queries[qklass.name.underscore][qname] = {
				"combine" => combine,
				"value" => value,
				"filters" => {}
			}
			qklass.filters_for(qname).each do |finst|
				fkey = "#{finst.class.name.underscore}:#{finst.name}"
				if fkeys.include?(fkey) then
					queries[qklass.name.underscore][qname]["filters"][finst.class.name] = {
						finst.name.to_s => "1"
					}
				end
			end
		end
		{query: queries}
	end
	
	def _parse_aggregation_keys(params)
		aggs = {}
		akeys = ((params[:akey] || params[:akeys]) || [])
		akeys = [akeys] unless akeys.is_a?(Array)
		akeys.flatten.each do |akey|
			aklass, aname = akey.split(":", 2)
			aklass = Aqua._get_klass(aklass, Aggregation)
			if aklass.nil? then
				next
				#return_status(status = 400, text = "#{akey} is invalid")
				#return true
			end
			aconf = (aklass.configuration[aname.to_sym] || aklass.configuration[aname.to_s])
			if aconf.nil? then
				next
				#return_status(status = 400, text = "#{akey} is invalid")
				#return true
			end
			aggs[aconf[:type].to_s] = {} if aggs[aconf[:type].to_s].nil?
			aggs[aconf[:type].to_s][aklass.name.underscore] = {} if aggs[aconf[:type].to_s][aklass.name.underscore].nil?
			aggs[aconf[:type].to_s][aklass.name.underscore][aname.to_s] = "1"
		end
		{aggregations: aggs}
	end
end
