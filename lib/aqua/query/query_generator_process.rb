class QueryGeneratorProcess
	
	def initialize(entities, generator_klasses, params)
		entities = [entities] unless entities.is_a?(Array)
		entities = Entity.find(entities) unless entities.first.is_a?(Entity)
		@entities = entities
		@generator_klasses = generator_klasses
		@params = params
		@jobs = {}
	end
	
	def generate_query()
		begin
			@generator_klasses.each do |generator_klass_name, generator_config|
				next unless generator_config["selected"] == "1"
				generator_klass = Kernel.const_get(generator_klass_name.to_sym) unless generator_klass_name.is_a?(Class)

				@jobs[generator_klass_name] = {
					_config: generator_config
				}
				@entities.each do |entity|
					generator = generator_klass.new(entity, @params.dup.merge(generator_config))
					result = generator.generate_query()
					@jobs[generator_klass_name][entity] = result
				end
			end
			summary = []
			@jobs.keys.each do |generator|
				@jobs[generator].keys.each do |ent|
					next if ent.is_a?(Symbol)
					vcids = @jobs[generator][ent][:varcallids]
					samples = Sample.where(id: @jobs[generator][ent][:parameters][:samples]).pluck(:name)
					varids = VariationCall.where(id: vcids).pluck(:variation_id).uniq
					summary << {
							id: "#{ent.id}_#{generator}",
							Generator: generator,
							Entity: ent.name,
							"#Variants" => varids.size,
							samples: samples,
							info: @jobs[generator][ent][:info],
							# options: @jobs[generator][:_config],
							query_definition: @jobs[generator][ent][:parameters]
					}.merge(@jobs[generator][:_config])
				end
			end
			@jobs[:_summary] = summary
			@jobs[:_params] = @params
			@jobs.to_yaml
		rescue RuntimeError => e
			if Rails.env == "production"
				now = Time.now.to_s
				Aqua.log_error("(#{now}) Query Generation Process failed")
				Aqua.log_error("(#{now}) #{e.message}")
				Aqua.log_error("(#{now}) #{e.backtrace.join("\n")}")
				# alert_and_back_or_redirect(message = msg, url = aqua_experiment_path(params[:id]))
				raise e
			else
				raise e
			end
		end

	end
	
end