class ApplicationController < ActionController::Base
	include CanCan::ControllerAdditions
  protect_from_forgery
  
  before_filter :check_login#, :log_request# , :get_my_jobs
  before_filter :log_request if Rails.env == "development"
  before_filter :access_required
	
	def filter_collection(collection, fields = [:name, :nickname], default_count = -1)
		@_render_collection_filter = fields
		klass = collection.arel.engine
		if klass.attribute_names.include?("updated_at") then
			collection = collection.order("#{klass.table_name}.updated_at DESC")
		end
		count = params[:count].to_s.to_i
		count = default_count if count == 0
		params[:count] = count if params[:count].nil?
		collection = collection.limit(count) if (count > 0)
		collection = collection.where(id: params[:ids]) unless params[:ids].nil?
		if !params[:_filter].nil? then
			collection_filter = params[:_filter]
			# make sure only valid fields are queries
			# fields = fields.map{|x| x.to_s} & klass.attribute_names
			fields.each do |f|
				next unless collection_filter[f]
				next if collection_filter[f] == ""
				vals = collection_filter[f]
				vals = vals.to_s.split(",").map(&:strip)
				f = "#{klass.table_name}.#{f}" unless f.to_s.index(".")
				conditions = vals.map{|val|
					get_collection_filter_condition(f, val, klass)
				}.flatten.join(" OR ")
				collection = collection.where(conditions) 
				
			end
		end
		collection
	end
	
	def alert_and_back_or_redirect(message = "Redirected.", url = "/", params = {})
		flash[:alert] = message
		if request.env["HTTP_REFERER"] then
			redirect_to(:back, :params => params.merge({status: 901}))
		else
			redirect_to(url, :params => params.merge({status: 901}))
		end
	end
	
  def admin_required
  	flash[:alert] = "You do not have access to this part of SNUPY"  unless current_user.is_admin
    # redirect_to('/') unless current_user.is_admin
    url = :back
    url = '/' unless request.env["HTTP_REFERER"] 
    redirect_to(url) unless current_user.is_admin
  end
	
	def access_required
		# d params
		# d "ApplicationController.access_required #####################"
		begin 
			# no authorization for home controller
			return if params[:controller].to_s == "" or params[:controller] == "home" or params[:controller] == "tools"
			action = (params[:action] || "").to_sym
			cntrl = (params[:controller] || "nil_classs")
			cntrl = cntrl.singularize #if cntrl.downcase != "specimen"
			mdl = nil
			begin
				mdl = Kernel.const_get(cntrl.camelcase)
			rescue NameError => e
			end
			if !mdl.is_a?(NilClass)
				# d "ApplicationController.access_required  #{action} -> #{mdl}"
				if mdl.respond_to?(:find) and !params[:id].nil? then
					begin
						# .becomes makes sure our definitions work for inheritance as well.
						inst = mdl.find(params[:id]).becomes(mdl)
						authorize! action, inst
					rescue ActiveRecord::RecordNotFound => e
						d "Record #{params[:id]} does not exist for #{mdl}"
						raise CanCan::AccessDenied.new(e.message)
					end
				else
					authorize! action, mdl 
				end
			else
				d "WARNING #{params} has no valid model."
			end
		rescue CanCan::AccessDenied
			d ActiveSupport::LogSubscriber::RED + ActiveSupport::LogSubscriber::BOLD +
					"ACCESS DENIED #{current_user.pretty_inspect}" +
					params.pretty_inspect +
				ActiveSupport::LogSubscriber::CLEAR
			redirect_to root_path, alert: "You don't have permission to access #{action} for #{mdl} (##{params[:id]})."
		end
	end
	## 
	# Gets all current jobs that belong to the user. This is used at different places so we put this in the application controller.
  def get_my_jobs(load_result=false, limit = nil)
  	long_job_ids = :all
  	
  	if !current_user.is_admin then
  		long_job_ids = LongJob.find_all_by_user(current_user.name, select: [:id]).map(&:id)
  	end
  	
  	if !load_result then
		limit = (limit || params[:count]).to_i
		limit = nil if limit.to_i <= 0
  		@user_jobs = LongJob.all_without_data(long_job_ids, {limit: limit})
		# @user_jobs = LongJob.where(id: @user_jobs)
  	else
  		@user_jobs = LongJob.find(long_job_ids)
	end
	
    return 	@user_jobs
  end
  
	def log_request()
		return true if Rails.env != "development"
		return true if defined?(::Rake)
		attrs = %w(REQUEST_METHOD PATH_INFO QUERY_STRING REQUEST_URI HTTP_CONNECTION HTTP_REFERER REQUEST_PATH)
		@@AQUALOCK.synchronize {
			# p "REQUEST AT #{Time.now.to_f}"
			# p request
			attrs.each do |a|
				"\t#{a} => #{request.env[a]}"
			end
			File.open("log/requests.log", "a+"){|f|
				f.write("[#{Time.now.to_f}] #{request.env["HTTP_REFERER"]} => #{request.env["REQUEST_METHOD"]} : #{request.env["REQUEST_PATH"]}\n")
				request.filtered_parameters.each do |k,v|
					tmp = v
					tmp = "#{tmp[0..10]}..." if v.is_a?(Array) and v.size > 10
					f.write("\t #{k}: #{tmp}\n")
				end
			}
		}
	end
	
	# See current_user
	def get_user()
		return current_user()
	end
  
  # Returns the <tt>User</tt> from the database by the HTTP-Headers user name, that can be configured using .htaccess files.
  def current_user()
		rem_user = http_remote_user()
    u = User.includes([:institutions, :affiliations]).find_by_name(rem_user)
		raise "User '#{http_remote_user()}' does not exist in #{Rails.env}" if u.nil?
		return u
  end
    
private
  def check_login
    raise ActiveRecord::RecordNotFound if not logged_in?
  end

  def current_user_id
    usr = current_user
    return nil if usr.nil?
    usr.id
  end

  def logged_in?
    ## check if the http_remote user field (provided by apache) contains a valid user name
    if current_user.nil? then
      num_users = User.all().size
      ## give us the chance to add at least one user
      return false if num_users > 0
    end
    return true
  end

  def http_remote_user
  	if Rails.env == 'development' then
  		default_user = params[:_user] || "developer"
		elsif Rails.env == "test" then
			default_user = params[:_user] || "normal_user"
		else
  		default_user = nil
	end
  	# default_user = "normal_user"
  	# default_user = "data_manager"
  	# default_user = "research_manager"
  	# default_user = "optimus"
		# default_user = "read_only"
		# default_user = "foreign_user"
  	return default_user if request.nil?
		return default_user if Rails.env == 'development' or Rails.env == 'test'
  	user = request.env['REMOTE_USER'] || request.env['HTTP_REMOTE_USER'] || request.headers['X-Forwarded-User']
    #if user.nil? then
    #  user = default_user if Rails.env == 'development' or Rails.env == 'test'
    #end
    user
  end

  helper_method :http_remote_user, :logged_in?, :current_user, :current_user_id

private
	def get_collection_filter_condition(f, val, klass)
		collection = klass
		if val.is_a?(Array) then
			collection = collection.where(f => val)
		elsif val.is_a?(String) then
			if val[0] == "/" and val[-1] == "/" then
				cond = val[1..-2]
				cond = ".*#{cond}.*"
				cond = ActiveRecord::Base::sanitize(cond)
				collection = collection.where("#{f} RLIKE #{cond}")
			elsif val[0..1] == ">=" then
				collection = collection.where("#{f} >= #{val[2..-1].to_i}")
			elsif val[0..1] == "<=" then
				collection = collection.where("#{f} <= #{val[2..-1].to_i}")
			elsif val[0] == ">" then
				collection = collection.where("#{f} > #{val[1..-1].to_i}")
			elsif val[1] == "<" then
				collection = collection.where("#{f} < #{val[1..-1].to_i}")
			else
				collection = collection.where(f => val)
			end
		end
		collection.arel.where_clauses
	end

end
