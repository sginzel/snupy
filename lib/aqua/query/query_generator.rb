class QueryGenerator
	extend ActiveSupport::DescendantsTracker
	@@CONFIG = {}
	def self.config_generator(*myopts)
		opts = myopts.dup.first
		opts[:name] = self.name if opts[:name].nil?
		opts[:label] = opts[:name] if opts[:label].nil?
		opts[:requires] = {} if opts[:requires].nil?
		@@CONFIG[self] = opts
	end
	
	def self.config
		@@CONFIG[self]
	end
	
	def initialize(entity, params)
		@entity = entity
		@params = params
		@info = [] # a string that can be used to give information about the parameter retrieval
	end

	def add_info(text)
		@info << text
	end

	def info
		@info.join("<br>").html_safe
	end
	
	def generate_query()
		# raise "not implemented - returns a new LongJob"
		experiment = Experiment.find(@params[:experiment])
		parameters = get_parameters
		if !parameters.nil? then
			parameters[:user] = (@params["user"] || @params[:user])
			parameters[:experiment] = (@params["experiment"] || @params[:experiment])
			parameters["user"] = parameters[:user]
			parameters["experiment"] = parameters[:experiment]
			varcallids = AquaQueryProcess.new(experiment).start(parameters)
		else
			varcallids = []
			parameters = {
					samples: [],
					failed: true
			}
		end

		#result = aaggprocess.start(parameters)
		#aaggprocess = AquaAggregationProcess.new(experiment, varcallids)
		#colors = aaggprocess.colors()
		{
				parameters: parameters,
				varcallids: varcallids,
				info: info()
		}
	end

	def get_parameters
		raise "not implemented"
	end

private
	def all_aggregations()
		all_agg = {}
		aquaagg = Aqua.aggregations
		aquaagg.keys.each do |aggklass|
			aggklassname = aggklass.name.underscore
			all_agg[aggklassname] = {}
			aquaagg[aggklass].each do |k, aggattr|
				next if aggattr[:type].to_s != "attribute"
				all_agg[aggklassname][k.to_s] = "1"
			end
		end
		all_agg
	end
end