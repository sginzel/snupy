# == Description
# AQuA is a small framework that enables different annotation tools to be implemented for SNuPy. It consists of three modules (Annotation, Query and Aggregation).
# Each module is independet from the other modules but the naming should be consistent when each module has references to a specific annotation tool.
# == File Structure
# - lib
#   - aqua
#     - annotation
#       - Annotation
#       - AquaAnnotationProcess
#     - query
#       - Filter
#       - Query
#     - aggregation
#       - Aggregation
# - extras
#   - aqua
#     - annotations
#       - tool1_name
#         - tool1.rb
#         - tool1_migration.rb
#         - tool1.rake
#       - tool2_name
#         - tool2.rb
#     - queries
#       - query1.rb
#       - query2.rb
#     - filters
#       - tool1
#         - filter1_tool1.rb
#         - filter2_tool1.rb
#       - tool2
#         - filter1_tool2.rb
#         - filter2_tool2.rb
#     - aggregations
#       - tool1
#         - aggregation1_tool1.rb
# == Attributes
# [no attributes] no attributes 
# == References
# * Annotation
# * Query / Filter
# * Aggregation
class Aqua
	extend ActiveSupport::DescendantsTracker
	extend AquaHelper
	extend AquaColor
#	extend SnupyAgain::Configurable
	
	## the organism hash is used so we can use :human as a reference in the has_attribute call
	@@ORGANISMS = {}
	@@ANNOTATIONS = {}
	@@QUERIES = {}
	@@AGGREGATIONS = {}
	@@ROUTES = {}
	@@ROUTE_PATHS = {}
	@SETTINGS = {}
	
	# holds logger objects that can be used during the AQuA process
	@@LOGGER = nil
	@@LOGLEVEL = :debug # :error, :warning, :info
	@@LOGLEVEL = :info if Rails.env == "production"
	@@last_error = nil
	
	def self.status(field = nil)
		begin
			model = Kernel.const_get("AquaStatus#{self.type.to_s.capitalize}")
		rescue NameError
			return nil
		end
		scope = model.where(source: self.name)
		scope = scope.where(status: field) unless field.nil?
		scope
	end
	
	# return specified aqua settings
	def self.settings(field = nil)
		config_file = File.join(Rails.root, "lib", "aqua", "settings.yaml")
		raise "AQUA settings.yaml not found" unless File.exists?(config_file)
		conf = YAML.load(File.open(config_file).read)
		raise "Setting for environment #{Rails.env} not found in #{config_file}" if conf[Rails.env].nil?
		cnf = {}
		conf[Rails.env].each do |k,v|
			cnf[k] = ERB.new(v.to_s).result(binding)
		end
		return cnf if field.nil?
		cnf[field]
	end
	
	def self.tempdir
		tmpdir = Aqua.settings("tmpdir")
		tmpdir = File.join("", "tmp") if tmpdir.nil?
		if !Dir.exists?(tmpdir)
			raise "[AQUA] #{tmpdir} does not exist!"
		end
		tmpdir
	end
	
	def self.cachedir
		cachedir = Aqua.settings("cachedir")
		cachedir = File.join("", "tmp", "aqua_cache") if tmpdir.nil?
		if !Dir.exists?(cachedir)
			raise "[AQUA] #{cachedir} does not exist!"
		end
		cachedir
	end
	
	def self.annotationdir
		File.join(Rails.root, "extras", "snupy_again", "aqua", "annotations")
	end
	
	def self.querydir
		File.join(Rails.root, "extras", "snupy_again", "aqua", "queries")
	end
	
	def self.filterdir
		File.join(Rails.root, "extras", "snupy_again", "aqua", "filter")
	end
	
	def self.aggregationdir
		File.join(Rails.root, "extras", "snupy_again", "aqua", "aggregations")
	end
	
	# return a list of possible organisms. Can be used to configure tools
	def self.organisms(name = :all)
		if @@ORGANISMS.size == 0 then
			@@ORGANISMS = Hash[Organism.all.map{|o| [o, o]}]
			@@ORGANISMS.keys.each do |o|
				@@ORGANISMS[o.name] = o
			end
			# TODO with 2.4 this didnt work for some reason. There has to be a new rails release to fix it.
			@@ORGANISMS[:human] = Organism.find_by_name("homo sapiens") # Organism.where(name: "homo sapiens")#
			@@ORGANISMS[:mouse] = Organism.find_by_name("mus musculus") # .where(name: "mus musculus")#
		else
			if name == :all then
				@@ORGANISMS.values.uniq
			end
		end
		return @@ORGANISMS if name.nil?
		@@ORGANISMS[name]
	end
	
	def self.register_annotation(klass, opts)
		mdl = (opts[:model] || opts["model"])
		mdl = mdl.first if mdl.is_a?(Array)
		mdl = mdl.keys.first if mdl.is_a?(Hash)
		if mdl.table_exists?
			@@ANNOTATIONS[klass] = opts
		end
	end
	
	def self.register_query(name, opts)
		@@QUERIES[self] = {} if @@QUERIES[self].nil? #opts
		raise "Query #{name} already registered for ##{self.name}" unless @@QUERIES[self][name].nil?
		@@QUERIES[self][name] = opts
	end
	
	def self.register_aggregation(name, opts)
		@@AGGREGATIONS[self] = {} if @@AGGREGATIONS[self].nil?
		 raise "Aggregation #{name} already registered for ##{self.name}" unless @@AGGREGATIONS[self][name].nil?
		@@AGGREGATIONS[self][name] = opts
	end

	def self.register_route(controller, method, verb, opts = {}, named_params = [])
		@@ROUTES ||= {}
		@@ROUTES[controller] ||= {}
		raise "Routes need to contain a :description (#{controller}/#{method})" if opts[:description].nil?
		url = "/#{controller}/#{method}"
		if named_params.size > 0 then
			url = url + "/" + named_params.map{|x| ":#{x}"}.join("/")
		end
		opts = {
				name: "#{controller.to_s}_#{method.to_s}",
				named_params: named_params,
				_url: url
		}.merge(opts)
		@@ROUTES[controller][method] ||= {}
		@@ROUTES[controller][method][verb] = opts
	end

	def self.route_paths()
		ret = []
		routes.each do |controller, methods_to_verbs|
			methods_to_verbs.each do |method, verbs|
				verbs.each do |verb, opts|
					ret << [opts[:description], opts[:_url]]
				end
			end
		end
		ret
	end

	def self.configuration(key = nil)
		if key.nil?
			((@@ANNOTATIONS[self] || @@QUERIES[self]) || @@AGGREGATIONS[self])
		else
			((@@ANNOTATIONS[self] || @@QUERIES[self]) || @@AGGREGATIONS[self])[key]
		end
	end

	def self.is_registered?(key)
		not (configuration(key.to_sym).nil? && configuration(key.to_s).nil?)
	end

	# return a list of available annotations
	def self.annotations
		@@ANNOTATIONS #Annotation.descendants
	end
	
	# return a hash that contains an entries for :simple and :complex queries
	def self.queries
		{
			simple: @@QUERIES.select{|k,v| k.is_simple?},
			complex: @@QUERIES.select{|k,v| k.is_complex?}
		}
	end
	
	def self.query_names
		(@@QUERIES[self] || {}).keys
	end
	
	# return all available aggregations
	def self.aggregations
		@@AGGREGATIONS
	end
	
	def self.group_aggregations
		find_aggregation_by_type("group")
	end
	
	def self.attribute_aggregations
		find_aggregation_by_type("attribute")
	end
	
	def self.find_aggregation_by_type(type = "attribute")
		ret = {}
		aggregations.each do |aklass, aconfs|
			attrconfs = aconfs.select{|aname, aconf|
				(aconf[:type] || aconf["type"]).to_s == type.to_s
			}
			if attrconfs.size > 0
				ret[aklass] = attrconfs
			end
		end
		ret
	end

	def self.routes
		@@ROUTES
	end

	def self.last_error
		ret = @@last_error
		@@last_error = nil
		ret
	end
	
	def self.last_error=(val)
		if @last_error.nil? then
			@@last_error = val.to_s
		else
			@@last_error = "#{val.to_s}\n#{@@last_error}"
		end
		@@last_error
	end
	
	def self.logger
		self._init_loggers()
		if Annotation.descendants.include?(self) or self == Annotation
			@@LOGGER[:annotation]
		elsif Query.descendants.include?(self) or self == Query
			@@LOGGER[:query]
		elsif Filter.descendants.include?(self) or self == Filter
			@@LOGGER[:query]
		elsif Aggregation.descendants.include?(self) or self == Aggregation
			@@LOGGER[:aggregation]
		elsif self == Aqua
			@@LOGGER[:aqua]
		else
			nil
		end
	end
	
	def self.log_fatal(message)
		self.last_error = message
		msg = "[FATAL #{Time.now.strftime("%F %T.%N")}](#{self.name}/#{caller.first.split("/").last}) #{message}"
		d msg.strip + "\n"
		if @@LOGLEVEL == :fatal or @@LOGLEVEL == :error or @@LOGLEVEL == :info or @@LOGLEVEL == :warning or @@LOGLEVEL == :debug
			self.logger.error(msg.strip + "\n")
		else
			return true
		end
	end
	
	def log_fatal(message)
		self.class.log_fatal message
	end
	
	def self.log_error(message)
		self.last_error = message
		msg = "[ERROR #{Time.now.strftime("%F %T.%N")}](#{self.name}/#{caller.first.split("/").last}) #{message}"
		d msg.strip + "\n"
		if @@LOGLEVEL == :error or @@LOGLEVEL == :info or @@LOGLEVEL == :warning or @@LOGLEVEL == :debug
			self.logger.error(msg.strip + "\n")
		else
			return true
		end
	end
	def log_error(message)
		self.class.log_error message
	end
	
	def self.log_warning(message)
		msg = "[WARNING #{Time.now.strftime("%F %T")}](#{self.name}) #{message}"
		d msg.strip + "\n"
		if @@LOGLEVEL == :info or @@LOGLEVEL == :warning or @@LOGLEVEL == :debug
			self.logger.warn(msg.strip + "\n")
		else
			return true
		end
	end
	def log_warning(message)
		self.class.log_warning message
	end
	
	def self.log_warn(message)
		self.log_warning(message)
	end
	def log_warn(message)
		self.class.log_warn message
	end
	
	def self.log_info(message)
		msg = "[INFO #{Time.now.strftime("%F %T")}](#{self.name}) #{message}"
		d msg.strip + "\n"
		if @@LOGLEVEL == :info or @@LOGLEVEL == :debug
			self.logger.info(msg.strip + "\n")
		else
			return true
		end
	end
	def log_info(message)
		self.class.log_info message
	end
	
	def self.log_debug(message)
		msg = "[DEBUG #{Time.now.strftime("%F %T.%N")}](#{self.name}) #{message}"
		d msg
		if @@LOGLEVEL == :debug
			self.logger.debug(msg)
		else
			return true
		end
	end
	def log_debug(message)
		self.class.log_debug message
	end
	
	def self.log(message)
		self.log_debug(message)
	end
	def log(message)
		self.class.log message
	end
	
	# parses the params structure for AQuA elements
	def self.parse_params(params)
		annotation_params = (params[:annotations] || params["annotations"] || []).dup
		query_params = (params[:queries] || params["queries"] || {}).dup
		aggregation_params = (params[:aggregations] || params["aggregations"] || {}).dup
		
		if annotation_params.is_a?(String) and annotation_params[0...3] == "---" then
			annotation_params = YAML.load(annotation_params)
		end
		if query_params.is_a?(String) and query_params[0...3] == "---" then
			query_params = YAML.load(query_params)
		end
		if aggregation_params.is_a?(String) and aggregation_params[0...3] == "---" then
			aggregation_params = YAML.load(aggregation_params)
		end
		
		annotations = annotation_params.map{|a|
			_get_klass(a, Annotation)
		}.delete_if(&:nil?)
		
		queries = {}
		query_params.each do |qklass, qname2opts|
			qklass = _get_klass(qklass, Query)
			if !qklass.nil?
				queries[qklass] = {}
				qname2opts.each do |qname, qparams|
					next unless qklass.is_registered?(qname)
					filters = (qparams[:filters] || qparams["filters"])
					value = (qparams[:value] || qparams["value"])
					next if value.nil?
					next if value == ""
					next if value == "0" && (qklass.configuration[qname.to_sym] || {})[:type] == :checkbox
					qfilters = qklass.find_filters_by_klass_and_name(qname, (filters || {}))
					if qfilters.size > 0 and (value || nil).to_s != "" then
						combine = (qparams[:combine] || qparams["combine"])
						qinst = qklass.create(qname, qfilters, value, (combine || "AND"), params)
						queries[qklass][qname] = qinst
					end
				end
				queries.delete(qklass) if queries[qklass].size == 0
			end
		end
		
		aggregations = {}
		aggregation_params.each do |atype, aconf|
			aggregations[atype] ||= []
			aconf.each do |aklassname, anames|
				aklass = _get_klass(aklassname, Aggregation)
				aggregations[atype] += anames.select{|aname, checked| checked == "1"}
																			.select{|aname, checked| aklass.is_registered?(aname)}
																			.map{|aname, checked| aklass.new(aname)}
																			.sort{|x,y| x.config[:colindex].to_i <=> y.config[:colindex].to_i}
			end 
		end
		
		{
			annotations: annotations,
			queries: queries,
			aggregations: aggregations
		}
		
	end
	
	# parses a class name to an acutal class object. Checks type for some sort of security
	def self._get_klass(name, type)
		ret = nil
		begin
			klass = name.to_s.camelcase
			ret = Kernel.const_get(klass)
			ret = nil unless type.descendants.include?(ret)
		rescue
			ret = nil
		end
		ret
	end
	
	# creates some example data
	def self._example_params()
		{
			annotations:  [:variant_effect_predictor_annotation],
			queries:      {
				#query_gene_id: { # queryklass
				#	gene_id: {     # queryname
				#		filters: {
				#			VepGeneIds: [:symbol, :ensg]
				#		},
				#		combine: "OR",
				#		value: "SMC3"
				#	}
				#},
				"query_variation_call" =>
					{
						"read_depth" =>
							{"value"   => "10",
							 "filters" => {
								 "FilterVariationCall" => {"vcdp" => "1"}
							 }
							},
						"varqual"    =>
							{"value"   => "30",
							 "filters" => {
								 "FilterVariationCall" => {"vcqual" => "0"}
							 }
							}
					},
				"query_gene_id" =>
					{
						"gene_id" =>
							{"value"   => "UBQLN4",
							 "filters" => {
								 "VepFilterGeneId" => {"vep_ens_symbol" => "1"}
							 }
							}
					}
			},
			aggregations: {
				"attributes" => {
					"aggregation_variation_call" => {
						"read_depth" => "1"
					}
				},
				"group"      => {
					"aggregation_group_by" => {
						"group_by_variation" => "1"
					}
				},
			}
		}
	end
	
	def self._aqua_files()
		# files = Dir["lib/aqua/**"]
		files = %w(lib/aqua/aqua_color.rb lib/aqua/aqua_helper.rb lib/aqua/aqua.rb lib/aqua/annotation/annotation.rb lib/aqua/query/query.rb lib/aqua/query/filter.rb lib/aqua/aggregation/aggregation.rb)
		files += %w(lib/aqua/query/query_generator.rb lib/aqua/query/query_generator_process.rb)
		files += %w(lib/aqua/aqua_status.rb)
		files += (Dir["lib/aqua/**/**"] - files)
		# files = files - ["lib/aqua/aqua_controller.rb"]
		# order is important because the filters need the queries to be initialized before in order to register properly
		# It is also imporant to load the _annotation classes last so they can reference the active record model. 
		files += Dir["extras/snupy_again/aqua/annotations/**/**"].select{|f| f =~ /\.rb$/}.sort
		files += Dir["extras/snupy_again/aqua/queries/**/**"].select{|f| f =~ /\.rb$/}.sort
		files += Dir["extras/snupy_again/aqua/filters/**/**"].select{|f| f =~ /\.rb$/}.sort
		files += Dir["extras/snupy_again/aqua/aggregations/**/**"].select{|f| f =~ /\.rb$/}.sort
		files += Dir["extras/snupy_again/aqua/generators/**/**"].select{|f| f =~ /\.rb$/}.sort
		files += Dir["extras/snupy_again/aqua/actions/**/**"].select{|f| f =~ /\.rb$/}.sort
		files.uniq
		files = files.map{|f| File.join(Rails.root, f)}
		files
	end
	
	def self._reload(force = false)
		if ((Rails.env != "production") or force) then
			puts "[WARNING] Realoading AQuA during production" if Rails.env == "production"
			puts "refreshing AQUA FROM: \n#{caller[0..3].join("\n")}" if Rails.env == "production"
			## unload all AQuA constants
			# klasses = ([Aqua] + Aqua.descendants)
			aqua2unload = [SimpleFilter, ComplexFilter, SimpleQuery, ComplexQuery, Annotation, Aggregation, Aqua, AquaController]
			klasses = []
			aqua2unload.each do |aqmod|
				klasses += aqmod.descendants
			end
			klasses += aqua2unload
			# clear descendants from tracker
			desc = ActiveSupport::DescendantsTracker.class_variable_get("@@direct_descendants")
			klasses.each do |aqmod|
				desc.delete(aqmod)
			end
			ActiveSupport::DescendantsTracker.class_variable_set("@@direct_descendants", desc)
			
			klasses =  klasses.flatten.map{|k| k.name.to_sym}.uniq
			@@AQUALOCK.synchronize {
				klasses.each do |klass|
					# d "    unloading #{klass}"
					Object.send(:remove_const, klass)
				end
				_init()
			}
		else
			d "Reloading of AQuA framework not allowed in production. Use force=true to force a reload on your own responsibility."
			false
		end
	end
	
	def self._init_loggers()
		if @@LOGGER.nil? then
			@@LOGGER = {
				aqua: Logger.new(File.join( Rails.root, "log", "aqua_#{Rails.env}-#{Socket.gethostname}.log"),1,5242880),
				annotation: Logger.new(File.join( Rails.root, "log", "aqua_annotation_#{Rails.env}-#{Socket.gethostname}.log"),1,5242880),
				query: Logger.new(File.join( Rails.root, "log", "aqua_query_#{Rails.env}-#{Socket.gethostname}.log"),1,5242880),
				aggregation: Logger.new(File.join( Rails.root, "log", "aqua_aggregation_#{Rails.env}-#{Socket.gethostname}.log"),1,5242880)
			}
		end
		@@LOGGER
	end
	
	# Loads all objects from AQuA to the object space
	def self._init()
		# puts "initializing AQUA"
		# puts "FROM: \n#{caller[0..3].join("\n")}"
		## load framework first
		files = _aqua_files()
		files.each do |file|
			next unless file =~ /\.rb$/
			print "   loading #{File.basename(file.gsub(Rails.root.to_s, "."))}".blue if Rails.env == "development"
			begin 
				load(file)
				print "    -> [OK]\n".green if Rails.env == "development"
			rescue => e
				print "    -> [FAIL] #{e.message}\n".red if Rails.env == "development"
			end
		end
		# load configuration
		self.settings()
		self._init_loggers()
		
		# now track if the annotation tools are ready
		# this is required because different machines 
		# can run different annotation processes and we 
		# want to keep track of their setup.
		Aqua.annotations.keys.each do |aqua_annot|
			aqua_annot.track_readiness
		end
		
		return true
	end
	
end
