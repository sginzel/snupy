module AquaRouter
	def self.load_aqua_routes
		SnupyAgain::Application.routes.draw do
			## take care of the query interface
			get "aqua/:action", controller: "aqua"
			post "aqua/:action", controller: "aqua"
			Aqua.routes.each do |controller, methods_to_verbs|
				methods_to_verbs.each do |method, verbs|
					verbs.each do |verb, opts|
						opts = opts.dup
						named_params = [opts.delete(:named_params)].flatten.reject(&:nil?)
						pathname = opts.delete(:_url)
						route = "#{controller}/#{method}"
						if named_params.size > 0
							route += "/" + named_params.map{|x| ":#{x}"}.join("/")
						end
						# name = opts.delete(:name)
						opts = {to: "#{controller}##{method}"}.merge(opts)
						if verb.to_s.downcase.to_sym == :get then
							get route, opts
						elsif verb.to_s.downcase.to_sym == :post then
							post route, opts
						end
					end
				end
			end
		end
	end
end