class Aggregation < Aqua
	
	attr_accessor :name, :requirements
	
	def self.batch_attributes(mdl, assoc = nil)
		attrs = mdl.attribute_names.reject{|attr| attr =~ /created_at|updated_at/}
		attrs.each do |attr|
			lblname = mdl.table_name
			lblname = mdl.aqua_table_alias if mdl.respond_to?(:aqua_table_alias)
			aname = "#{lblname}.#{attr}"
			if assoc.nil? then
				req = { mdl => [attr.to_sym] }
			else
				req = {
					assoc => {
						mdl => [attr.to_sym]
					}
				}
			end
			self.register_aggregation aname.to_sym,
												label: aname,
												colname: aname,
												colindex: 0,
												aggregation_method: attr.to_sym,
												type: :batch,
												category: "#{mdl.name}",
												requires: req
		end
	end
	
	def self.register_aggregation(name, opts)
		Aqua.log_warning("AGGREGATION #{name} is NOT ACTIVE") unless opts[:active].nil? or opts[:active] == true
		return false unless opts[:active].nil? or opts[:active] == true
		raise "Aggregation needs an :aggregation_method" if opts[:aggregation_method].nil?
		opts[:category] = "Miscellaneous" if opts[:category].nil?
		raise "Aggregation requires attribute is neccessary." if opts[:requires].nil?
		super(name, opts)
	end
	
	def self.create(name)
		self.new(name, arr)
	end
	
	def self.add_required(scope, 
												aname, 
												add_select = true, 
												organismid = nil,
												models2skip = [])
		required = (self.configuration[aname.to_s] || self.configuration[aname.to_sym])[:requires]
		super(scope, add_select, organismid, required, models2skip)
	end
	
	def self.applicable?(aname)
		required = (self.configuration[aname.to_s] || self.configuration[aname.to_sym])[:requires]
		Aqua.is_applicable?(required)
	end
	
	def self.linkout(label, url = nil)
		return nil if label.nil?
		if label.is_a?(String) then
			return nil if label.strip == ""
		end
		if !url.nil? then
			if url.is_a?(String) then
				# ActionController::Base.helpers.link_to(label, url) # would be nicer, but does a lot of stuff we dont need and drags down the performance
				"<a href=\"#{url}\">#{label}</a>".html_safe
			elsif url.is_a?(Hash) then
				"<a href=\"#{url.values.first}\" data-context='#{url.to_json}'>#{label}</a>".html_safe
			else
				"#{label}->#{url}".html_safe
			end
		else
			self.linkout(label[:label], label[:url])
		end
	end
	
	def self.aggregate_all(aggregations)
		
	end

	def self.get_aggregation_colors()
		attr_aggregations = Aqua.attribute_aggregations
		column2color = {}
		attr_aggregations.each do |aklass, aconfs|
			aconfs.each do |aname, aconf|
				next if aconf[:color].nil?
				if aconf[:color].is_a?(Hash) then
					column2color.merge!(aconf[:color])
				else
					column2color.merge!({aconf[:colname] => aconf[:color]})
				end
			end
		end
		column2recordcolor = {}
		attr_aggregations.each do |aklass, aconfs|
			aconfs.each do |aname, aconf|
				next if aconf[:record_color].nil?
				if aconf[:record_color].is_a?(Hash) then
					column2recordcolor.merge!(aconf[:record_color])
				else
					column2recordcolor.merge!({aconf[:colname] => aconf[:record_color]})
				end
			end
		end
		{
				colors: column2color,
				record_color: column2recordcolor
		}
	end
	
	def self.akey(aname)
		sprintf("%s:%s", self.name.underscore, aname)
	end
	
	def akey()
		self.class.akey(self.name)
	end

	def initialize(aname)
		@name = aname
		@requirements = (config[:requires])
		@aggregation_performed = false
		@aggregated_colnames = []
		@cache = Hash.new{|hash, key|
			hash[key] = {}
			hash[key]
		}
		@cache = {}
		@aggregation_lambda_cache = {}

		raise "Aggregation #{@name} not registered for #{self.class.name}" if config[:aggregation_method].nil?
	end
	
	def linkout(label, url = nil)
		self.class.linkout(label, url)
	end
	
	def colnames()
		if !@aggregation_performed then
			raise "[#{self.class.name}] we can only determine the column name after at least one aggregation process"
		end
		@aggregated_colnames
	end
	
	def config()
		(self.class.configuration[@name.to_sym] || self.class.configuration[@name.to_s] || {})
	end
	
	def configuration()
		config()
	end
	
	def add_required(scope, organismid)
		self.class.add_required(scope, @name, true, organismid)
	end
	
	def execute_hook(arr, conf, hook, params = nil)
		begin
			if !conf[hook].nil? then
				if self.respond_to?(conf[hook].to_sym)
					hookmethod = self.method(conf[hook].to_sym)
					if !params.nil? &&  hookmethod.arity.to_i.abs == 2
						self.send(conf[hook].to_sym, arr, params)
					else
						self.send(conf[hook].to_sym, arr)
					end
				elsif conf[hook].is_a?(Proc) then
					if conf[hook].lambda? then
						if !params.nil? && conf[hook].arity.to_i.abs == 2
							conf[hook].call(arr, params)
						else
							conf[hook].call(arr)
						end
					else
						if !params.nil? && conf[hook].arity.to_i.abs == 2
							lambda {|x, p| conf[hook].call(x, p)}.call(arr, params)
						else
							lambda {|x| conf[hook].call(x)}.call(arr)
						end
					end
				else
					raise "Hook #{conf[hook]} not found in #{self}"
				end
			end
		rescue RuntimeError => e
			self.log_error("Error excuting prehook (#{conf[hook].to_sym}) in #{self.class}")
			self.log_error(conf.pretty_inspect)
			self.log_error(e.backtrace.join("\n"))
			raise e
		end
	end
	
	def aggregate(arr, params = nil)
		begin
			conf = config()
			execute_hook(arr, conf, :prehook, params)
			arr.each do |record_key, recs|
				recs.each do |rec|
					aggregated_value = _get_aggregate_value(conf[:aggregation_method], rec, (params || {}))
					# if a Hash is returned by the aggregation method
					# we expand the result hash by the keys and values of the aggregation
					if (aggregated_value.is_a?(Hash)) then
						aggregated_value.each do |k,v|
							colname = "#{conf[:colname]}[#{k}]"
							@aggregated_colnames << colname unless @aggregation_performed
							rec[colname] = v
						end
					else
						@aggregated_colnames << conf[:colname] unless @aggregation_performed
						rec[conf[:colname]] = aggregated_value
					end
					@aggregation_performed = true
				end
			end
			execute_hook(arr, conf, :posthook)
			@aggregation_performed = true
		rescue RuntimeError => e
			self.log_error("Error during aggregation #{self.class}")
			self.log_error(conf.pretty_inspect)
			self.log_error(e.backtrace.join("\n"))
			raise e
		end
	end
	
	def aggregate_group(rec)
		conf = config()
		record_key = _get_aggregate_value(conf[:aggregation_method], rec)
		@aggregation_performed = true
		record_key
	end
	
	def _get_aggregate_value(aggregate_with, record, params = {})
		begin
			if (aggregate_with.is_a?(Proc)) then
				if aggregate_with.lambda? then
					if aggregate_with.arity.to_i.abs == 1 then
						record_key = aggregate_with.call(record)
					elsif aggregate_with.arity.to_i.abs >= 2 then
						record_key = aggregate_with.call(record, params)
					else
						raise "too few parameters (#{aggregate_with.arity}) accepted by aggregation #{aggregate_with}"
					end
				else
					@aggregation_lambda_cache[aggregate_with] = lambda {|r| aggregate_with.call(r)} if @aggregation_lambda_cache[aggregate_with].nil?
					if @aggregation_lambda_cache[aggregate_with].arity.to_i.abs == 1 then
						record_key = @aggregation_lambda_cache[aggregate_with].call(record) # if the block was created with Proc.new the return statement in that block triggers the return in this function. we dont want this...
					elsif @aggregation_lambda_cache[aggregate_with].arity.to_i.abs >= 2 then
						record_key = @aggregation_lambda_cache[aggregate_with].call(record, params)
					else
						raise "too few parameters (#{aggregate_with.arity}) accepted by aggregation #{aggregate_with}"
					end
				end
			elsif not self.respond_to?(aggregate_with.to_sym)
				record_key = (record[aggregate_with] || record[aggregate_with.to_s])
			else
				if self.method(aggregate_with.to_sym).arity.to_i.abs == 1
					record_key = self.send(aggregate_with.to_sym, record)
				elsif self.method(aggregate_with.to_sym).arity.to_i.abs >= 2
					record_key = self.send(aggregate_with.to_sym, record, params)
				end
			end
		rescue => e
			Aggregation.log_error("#{@name} -> #{aggregate_with} FAILED #{self.config}".magenta)
			raise e
		end
		record_key
	end
	
end
