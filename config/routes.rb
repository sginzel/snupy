SnupyAgain::Application.routes.draw do
	
	resources :reports do
		member do
			get 'download'
		end
	end
	Report.subclasses.each do |k|
		puts k.name.underscore.pluralize.red
		resources k.name.underscore.pluralize, :controller => 'reports'
	end
	
	
	resources :entity_groups do
		collection do
			get 'batch_create'
			post 'batch_create'
			post 'show_dataset_summary'
			post 'assign_entity'
		end
	end
	# get 'specimen_probe' => "specimen_probes#index"
	
	resources :entities do
		collection do
			post 'assign_specimen_probe'
			post 'assign_entity_group'
			post 'assign_tags'
		end
		member do
			post 'show'
		end
	end
	
	resources :specimen_probes do
		collection do
			post 'assign_sample'
			post 'assign_entity'
			post 'assign_tags'
		end
	end
	
	resources :tags
	
	match 'long_jobs/clear_cache' => 'long_jobs#clear_cache', :as => "long_jobs_clear_cache", :via => "delete"
	match 'long_jobs/list' => 'long_jobs#list', :via => "get"
	match 'long_jobs/statistics' => 'long_jobs#statistics', :via => "get"
	match 'long_jobs/statistics' => 'long_jobs#statistics', :via => "post"
	match "long_jobs/:id/status" => 'long_jobs#status', :as => "long_job_status", :via => "get"
	match 'long_jobs/:id' => 'long_jobs#result', :as => "long_job_result", :via => "get"
	match 'long_jobs/:id/result' => 'long_jobs#result', :via => "get"
	match 'long_jobs/:id/kill' => 'long_jobs#destroy', :as => "long_job_kill", :via => "delete"
	match 'long_jobs' => 'long_jobs#index', :via => "get"
	
	
	#resources :long_jobs do
	#  collection do
	#    delete 'clear_cache'
	#  end
	#  member do
	#    get 'status'
	#    get 'result'
	#  end
	#end
	
	resources :users do
		member do
			get 'longtask'
		end
		collection do
			get 'access_control_list'
		end
	end
	
	get "api", to: "home#api", as: "api"
	post "api", to: "home#api", as: "api"
	get "api_form", to: "home#api_form", as: "api_form"
	post "api_form", to: "home#api_form", as: "api_form"
	
	get "home/index"
	
	get "home/cookies"
	
	get "home/about"
	
	get "home/help"
	
	get "home/citation"
	
	get "home/aqua"
	get "home/show_log"
	post "home/show_log_details"
	post "home/destroy_log"
	
	get "aqua/query_collection/:qklass/:qname", to: "aqua#query_collection", as: "aqua_query_collection"
	get "aqua/query_details/:variation_id", to: "aqua#query_details", as: "aqua_query_details"
	post "aqua/query_details/:variation_id", to: "aqua#query_details", as: "aqua_query_details"
	
	# tools
	get "tools/ppi_network"
	post "tools/ppi_network"
	get "tools/gene_details"
	post "tools/gene_details"
	
	resources :institutions, :generic_lists, :generic_gene_lists, :generic_region_lists
	resources :sample_tags
	#	resources :query_filters do
	#		collection do
	#			get 'resource_method'
	#		end
	#		member do
	#			get 'filterCollection'
	#		end
	#	end
	resources :samples do
		collection do
			put 'refreshstats'
			get 'claimable'
			get 'refreshindex'
			post 'mass_destroy'
			post 'force_reload'
			post 'sample_similarity'
			post 'assign_specimen'
			post 'gender_coefficient'
			post 'refresh_stats'
		end
		member do
			get 'detail'
			post 'detail'
			put 'collectstats'
		end
	end
	
	resources :experiments do
		collection do
			post 'details'
			post 'more_details'
			get 'details'
			get 'more_details'
			post 'interactions'
			post 'interaction_details'
			post 'attribute_matrix'
			post 'panel_to_subject_matrix'
			post 'save_resultset'
		end
		member do
			get 'aqua'
			post 'aqua'
			get 'query_generator'
			post 'query_generator'
			get 'query', to: redirect('/experiments/%{id}/aqua')
		end
	end
	get 'experiments/aqua_meta/:user/:organism', controller: :experiments, action: :aqua_meta, as: :aqua_meta #=> "experiments#aqua_meta"
	
	# redirect so experiments can be called projects
	get '/projects', to: redirect('/experiments')
	get '/projects/:id', to: redirect('/experiments/%{id}')
	
	resources :vcf_files do
		member do
			get 'annotate'
			get 'aqua_annotate'
			get 'download'
			post 'aqua_annotate_single'
		end
		collection do
			get 'batch_submit'
			post 'batch_submit'
			post 'create_sample_sheet'
			post 'download_sample_sheet'
			post 'assign_tags'
			post 'baf_plot'
			post 'mass_destroy'
			get 'baf_plot'
			get 'download_sample_sheet'
			get 'refreshindex'
		end
	end
	## VIA http://stackoverflow.com/questions/5720100/single-table-inheritance-and-routing-in-ruby-on-rails-3-0
	resources :vcf_file_varscans, :controller => "vcf_files", :type => "VcfFileVarscan"
	resources :vcf_file_excavators, :controller => "vcf_files", :type => "VcfFileExcavator"
	
	# The priority is based upon order of creation:
	# first created -> highest priority.
	
	# Sample of regular route:
	#   match 'products/:id' => 'catalog#view'
	# Keep in mind you can assign values other than :controller and :action
	
	# Sample of named route:
	#   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
	# This route can be invoked with purchase_url(:id => product.id)
	
	# Sample resource route (maps HTTP verbs to controller actions automatically):
	#   resources :products
	
	# Sample resource route with options:
	#   resources :products do
	#     member do
	#       get 'short'
	#       post 'toggle'
	#     end
	#
	#     collection do
	#       get 'sold'
	#     end
	#   end
	
	# Sample resource route with sub-resources:
	#   resources :products do
	#     resources :comments, :sales
	#     resource :seller
	#   end
	
	# Sample resource route with more complex sub-resources
	#   resources :products do
	#     resources :comments
	#     resources :sales do
	#       get 'recent', :on => :collection
	#     end
	#   end
	
	# Sample resource route within a namespace:
	#   namespace :admin do
	#     # Directs /admin/products/* to Admin::ProductsController
	#     # (app/controllers/admin/products_controller.rb)
	#     resources :products
	#   end
	
	# You can have the root of your site routed with "root"
	# just remember to delete public/index.html.
	root :to => 'home#index'
	# See how all your routes lay out with "rake routes"
	AquaRouter.load_aqua_routes

# This is a legacy wild controller route that's not recommended for RESTful applications.
# Note: This route will make all actions in every controller accessible via GET requests.
# match ':controller(/:action(/:id))(.:format)'
end
