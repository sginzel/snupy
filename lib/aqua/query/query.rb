class Query < Aqua
	@@FILTERS = {}
	
	attr_reader :value, :combine, :priority, :params, :config, :name
	
	# We overwrite the configure method to set the default_by_type parameter
	def self.set_defaults(opts)
		opts[:type] = :text if opts[:type].nil?
		if opts[:default].nil? then
			default_by_type = {
				nil: "", # Make it a text
				text: "", # FIELD = X
				textarea: "", # FIELD = X
				delimtext: "", # FIELD IN (X1, X2) 
				number: 0, # FIELD = X
				numeric: 0, # FIELD = X
				range: [0,100, 50, 75], # [min, max, defaultmin, defaultmax] BETWEEN X AND Y
				range_gt: [0, 100, 50], # [min, max, default] FIELD > X
				range_lt: [0, 100, 50], # [min, max, default] FIELD < X
				select: [], # Give single selection option FIELD = X
				options: :collection, # Open option diaglog for multiple options: FIELD IN (X1, X2)
				checkbox: false, # Perform filter if X = 1
				checktext: false # If checked give parameter for filter by text box
			}
			opts[:default] = default_by_type[opts[:type]]
		end
		opts[:combine] = "AND" if opts[:combine].nil?
		# Should the query process splice up the sample ids into batches to make processing smother?
		opts[:use_query_splicing] = true if opts[:use_query_splicing].nil?
		opts[:batch] = false if opts[:batch].nil?
		opts
	end
	
	def self.register_query(name, opts)
		Aqua.log_warning("QUERY #{name} is NOT ACTIVE") unless opts[:active].nil? or opts[:active] == true
		return false unless opts[:active].nil? or opts[:active] == true
		opts[:type] = :text if opts[:type].nil?
		opts = set_defaults(opts)
		super(name, opts)
	end
	
	def self.register_batch_query(klass, column_to_type)
		column_to_type.each do |cname, type|
			qname = Query.get_qname(klass, cname)
			QueryBatch.register_query qname,
									  label: "Batch filters #{qname}",
									  default: "",
									  type: type,
									  organism: [@@ORGANISMS[:human], @@ORGANISMS[:mouse]],
									  priority: 0,
									  combine: "AND",
									  batch: true
		end
	end
	
	def self.get_qname(klass, attribute_name)
		"#{klass.table_name}.#{attribute_name}".to_sym
	end
	
	def self.configuration_for(qname)
		(self.configuration[qname] || self.configuration[qname.to_s] || self.configuration[qname.to_sym])
	end
	
	# registers a filter and a method 
	def self.register_filter(qname, filter)
		# d "         -> Register filter for #{self}:#{qname} => #{filter}"
		# check if filter meets requirements
		if filter.applicable?() or 1 == 1 then
			@@FILTERS[self] = {} if @@FILTERS[self].nil?
			@@FILTERS[self][qname] = [] if @@FILTERS[self][qname].nil?
			@@FILTERS[self][qname] << filter
		else
			d "    [WARNING] Filter is not applicable."
		end
	end
	
	# select filters based on fklass_to_name
	# fklass_to_name has this structure: 
	#  { 
	#    "FilterKlass" => {"filtername" => "0", "filtername1" => "1"},
	#    "FilterKlassOther" => {"other_filtername" => "0", "other_filtername" => "1"},
	#  }
	def self.find_filters_by_klass_and_name(qname, fklass_to_name)
		available_filters = filters_for(qname)
		ret = []
		fklass_to_name.each do |fklass, fnames|
			selected_names = []
			fnames.each do |fname, selected|
				selected_names << fname if selected.to_s == "1"
			end
			selected_names.each do |selected_name|
				ret << available_filters.select{|finst| finst.class.name == fklass.to_s && finst.name.to_s == selected_name}
			end
		end
		ret.flatten.uniq
	end
	
	def self.filters_for(qname)
		if @@FILTERS[self].nil?
			# puts "No filters available for #{self.name}:#{qname}"
			return []
		else
			(@@FILTERS[self][qname.to_s] || @@FILTERS[self][qname.to_sym])
		end
	end
	
	def self.filters(qname = nil, qklass = self)
		if !qname.nil?
			((@@FILTERS[qklass] || {})[qname] || [])
		else
			(@@FILTERS[qklass] || {})
		end
	end
	
	def self.all_filters
		@@FILTERS
	end
	
	def self.is_simple?()
		SimpleQuery.descendants.include?(self)
	end
	
	def self.is_complex?()
		ComplexQuery.descendants.include?(self)
	end
	
	def self.create(queryname, filters, value, combine, params)
		self.new(queryname, filters, value, combine, params)
	end
	
	def self.get_collection(qklass, qname, params)
		ret = []
		unique_collection_methods = {}
		filters(qname, qklass).each do |f|
			unique_collection_methods[[f.class, f.collection_method]] = {filter: f, method: f.collection_method, params: params}
		end
		
		unique_collection_methods.values.flatten.uniq.each do |call_conf|
			begin
				ret += call_conf[:filter].send(call_conf[:method], call_conf[:params])
			#rescue Exception => e
			#	self.log_error("Error excuting filter (#{call_conf[:method].to_sym}) in #{self.class}")
			#	self.log_error(e.message)
			#	self.log_error(call_conf.pretty_inspect)
			#	self.log_error(e.backtrace.join("\n"))
			#	raise e
			end
		end
		
		ret = [{info: "No filters available."}] if ret.size == 0
		ret.each do |rec|
			if !rec[:id].nil? then
				rec["Select"] = rec[:id] if rec["Select"].nil?
			end
		end
		# d ret
		ret.uniq
	end
	
	def self.qkey(qname)
		sprintf("%s:%s", self.name.underscore, qname)
	end
	
	def qkey()
		self.class.qkey(self.name)
	end
	
	def initialize(queryname, filters, value, combine, params)
		@config = self.class.configuration_for(queryname)
		@name = queryname
		@params = params
		
		raise "No config found for #{self.class}[#{queryname}]" if @config.nil?
		@available_filters = self.class.filters_for(queryname)
		raise "No filters available for #{self.class.name}:#{queryname}" if @available_filters.nil?
		@filters = filters.map(&:dup)
		raise "No filter selected" if @filters.nil? or @filters.size == 0
		
		@priority = @config[:priority]
		@value = value
		## make sure the value is properly sanitized
		@value = case @config[:type]
					 when :numeric
						 ActiveRecord::Base::sanitize(@value).gsub("'", "").to_i
					 when :number
						 ActiveRecord::Base::sanitize(@value).gsub("'", "").to_i
					 when :integer
						 ActiveRecord::Base::sanitize(@value).gsub("'", "").to_i
					 when :double
						 ActiveRecord::Base::sanitize(@value).gsub("'", "").to_f
					 when :float
						 ActiveRecord::Base::sanitize(@value).gsub("'", "").to_f
					 when :select
						 ActiveRecord::Base::sanitize(@value.to_s) #@value.map{|v| ActiveRecord::Base::sanitize(v)}
					 when :text
						 ActiveRecord::Base::sanitize(@value.to_s)
					 when :textarea
						 @value.to_s
					 when :delimtext
						 if @value.is_a?(String)
						 	@value.split(/[,;\n]/, -1).reject{|v| v.to_s == ""}.map{|v| ActiveRecord::Base::sanitize(v.strip)}
						 else
							 @value = [@value] unless @value.is_a?(Array)
							 @value.reject{|v| v.to_s == ""}.map{|v| ActiveRecord::Base::sanitize(v.strip)}
						 end
					 when :collection # check if the collection is a number by converting it to a string and back.
						 if @value.is_a?(String)
							 @value.split(",", -1).map{|v| (v.to_s == v.to_i.to_s)?(v.to_i):ActiveRecord::Base::sanitize(v)}
						 else
							 @value = [@value] unless @value.is_a?(Array)
							 @value.map{|v| (v.to_s == v.to_i.to_s)?(v.to_i):ActiveRecord::Base::sanitize(v)}
						 end
					 when :multiselect
						 if @value.is_a?(String)
						 	@value.split(",", -1).map{|v| (v.to_s == v.to_i.to_s)?(v.to_i):ActiveRecord::Base::sanitize(v)}
						 else
							 @value = [@value] unless @value.is_a?(Array)
							 @value.map{|v| (v.to_s == v.to_i.to_s)?(v.to_i):ActiveRecord::Base::sanitize(v)}
						 end
					 when :checktext
						 ActiveRecord::Base::sanitize(@value.to_s)
					 when :options
						 ActiveRecord::Base::sanitize(@value.to_s)
					 when :checkbox
						 @value.to_s == "1"
					 when :range
						 [ActiveRecord::Base::sanitize(@value).split("-")[0], ActiveRecord::Base::sanitize(@value).split("-")[1]]
					 when :range_gt
						 ActiveRecord::Base::sanitize(@value).gsub("'", "").to_i
					 when :range_lt
						 ActiveRecord::Base::sanitize(@value).gsub("'", "").to_i
					 else
						 ""
				 end
		@combine = combine
		raise "Only OR or AND are allowed, but '#{@combine}' given." unless combine == "AND" or combine == "OR"
	end
	
	def filters
		(@filters || [])
	end
	
	# The query method handles different ways of combining the filters
	def query(scope_or_array, params_adjustments = {})
		raise ArgumentError.new("Not implemented for super class")
	end
	
	def add_required(scope, add_select, organismid)
		@filters.each do |f|
			next unless f.add_requirements
			next if f.nil? or f.requirements == [] or f.requirements.size == 0
			scope = Aqua.add_required(scope, add_select, organismid, f.requirements)
		end
		scope
	end

end

class SimpleQuery < Query
	def query(scope, params_adjustments = {})
		return scope if @config[:type] == :checkbox and @value == false
		where_cond = filters_to_sql(scope, params_adjustments)
		return nil if where_cond.nil?
		if where_cond.to_s != "" then
			return scope.where(where_cond)
		else
			return scope
		end
	end
	
	def filters_to_sql(scope, params_adjustments = {})
		sql = []
		helpr = scope.except(:where)
		helpr_used = false
		@filters.each do |f|
			#begin
				condition = f.filter(@value, @params.merge(params_adjustments), self)
			#rescue Exception => e
			#	self.log_error("Error excuting filter (#{f}) in Query #{self.class}")
			#	self.log_error(f.pretty_inspect)
			#	self.log_error("VALUE:")
			#	self.log_error(@value.pretty_inspect)
			#	self.log_error("PARAMETERS:")
			#	self.log_error(@params.pretty_inspect)
			#	self.log_error(e.backtrace.join("\n"))
			#	raise e
			#end
			return nil if condition.nil? # this happens when the mapping breaks because a filter reaches a un-fulfilable condition.
			# if the filter returns an empty condition it means 
			# he wants us to proceed because he wont contribute
			# and filter criteria based on the user input
			# this can happen when the user wants to select all variants 
			# which are present in at least 1 sample
			if condition.is_a?(String)
				sql << condition unless condition == ""
			elsif condition.is_a?(Array) then
				sql << ActiveRecord::Base.send(:sanitize_sql_array, condition)
			else
				helpr = helpr.where(condition) unless condition.size == 0
				helpr_used = true unless condition.size == 0
			end
		end
		# we use Arel library to create the where condition
		# using this we can support string returns from filters 
		# and also hashes as filters
		if (helpr_used or sql.size > 0) then
			visitor = Arel::Visitors::ToSql.new helpr.connection
			# surround every condition with brackets before combining them
			sql_statement = (helpr.where_values.map {|c| visitor.accept c} + sql).map{|x| "(#{x})"}.join(" #{@combine} ")
			# sql = sql.join(" #{@combine} ")
			"(#{sql_statement})" # surround with brackets
		else
			return ""
		end
	end

end

class ComplexQuery < Query
	def query(arr, params_adjustments = {})
		return arr if @config[:type] == :checkbox and @value == false
		return arr if arr.size == 0 # dont attempt to process empty results
		if @combine == "OR" then
			query_or(arr, params_adjustments)
		elsif @combine == "AND"
			query_and(arr, params_adjustments)
		else
			raise "Only AND and OR are allowed for combine"
		end
	end
	
	def query_or(arr, params_adjustments)
		# create a hash that contains whether a variation_call survived at least one filter
		survived_one_filter = Hash[arr.map{|rec| [rec["variation_calls.id"], false]}]
		process.default = false
		@filters.each{|f|
			#begin
				paramarr = arr.select{|rec| !survived_one_filter[rec["variation_calls.id"]]}
				farr = f.filter(paramarr, @value, @params.merge(params_adjustments), self)
				farr.each do |rec|
					survived_one_filter[rec["variation_calls.id"]] = true
				end
			#rescue Exception => e
			#	self.log_error("Error during query_or #{self.class}")
			#	self.log_error(f.pretty_inspect)
			#	self.log_error("VALUE:")
			#	self.log_error(@value.pretty_inspect)
			#	self.log_error("PARAMETERS:")
			#	self.log_error(@params.pretty_inspect)
			#	self.log_error(e.backtrace.join("\n"))
			#	raise e
			#end
		}
		arr.select{|rec| survived_one_filter[rec["variation_calls.id"]]}
	end
	
	def query_and(arr, params_adjustments)
		@filters.each{|f|
			#begin
				arr = f.filter(arr, @value, @params.merge(params_adjustments), self)
			#rescue Exception => e
			#	self.log_error("Error during query_and #{self.class}".red)
			#	d "END OF ERROR"
			#	d error.message.red
			#	d "END OF ERROR"
			#	self.log_error("MESSAGE #{e.message}".red)
			#	self.log_error(f.pretty_inspect)
			#	self.log_error("VALUE:")
			#	self.log_error(@value.pretty_inspect)
			#	self.log_error("PARAMETERS SET:")
			#	self.log_error(@params.keys.pretty_inspect)
			#	self.log_error(e.backtrace[0..15].join("\n"))
			#	raise e
			#end
		}
		arr
	end

end