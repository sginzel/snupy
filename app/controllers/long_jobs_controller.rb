class LongJobsController < ApplicationController
	include LongJobStatisticsHelper
	before_filter :admin_required, :only => [ :new, :edit, :create, :delete, :destroy, :update ]
	def list
		@long_jobs = get_my_jobs(false, params[:count])
		@long_jobs.sort!{|x,y|
			y.created_at <=> x.created_at
		}
		# @jobstats = Hash[LongJob.connection.execute("SELECT status, COUNT(id) FROM long_jobs GROUP BY status").to_a]
		@jobstats = {}
		@long_jobs.each do |lj|
			@jobstats[lj.status] = @jobstats[lj.status].to_i + 1
		end
		respond_to do |format|
			format.html { render partial: "joblist"}
			format.json { render json: @long_jobs }
		end

	end

	# GET /long_jobs
	# GET /long_jobs.json
	def index
		# @long_jobs = LongJob.all
		#if params["count"].nil? then
		#	redirect_to action: "index", count: 1000
		#	return true
		#end
		# @long_jobs = get_my_jobs(false)
		attr_wo_data = LongJob.attribute_names - ["result"]
		if !current_user.is_admin? then
			d "SELECT----------------"
			@long_jobs = LongJob.where(user: current_user.name).select(attr_wo_data)
		else
			d "SELECT----------------X"
			@long_jobs = LongJob.select(attr_wo_data)
		end
		@long_jobs = filter_collection @long_jobs, [:delayed_job_id, :queue, :title, :user, :handle, :method, :status]
		
		@num_jobs = @long_jobs.size
		@long_jobs.sort!{|x,y|
			y.created_at <=> x.created_at
		}
		@job_threshold = (params["count"] || 1000).to_i
		@job_threshold = 1 if @job_threshold <= 0
		if !(params["count"].to_s == "all") then
			@long_jobs = @long_jobs[0...@job_threshold]
		end
		respond_to do |format|
			format.html # index.html.erb
			format.json { render json: @long_jobs }
		end
	end

	# GET /long_jobs/1
	# GET /long_jobs/1.json
	def show
		@long_job = LongJob.find(params[:id])

		respond_to do |format|
			format.html # show.html.erb
			format.json { render json: @long_job }
		end
	end

	# Takes 2 parameters and renders the status view of LongJob
	# id:: LongJob ID
	# target:: HTML container name to put the status message in - default is "snupy_job_status"
	def status
		@long_job = LongJob.find(params[:id])
		params[:target] = "snupy_job_status" if params[:target].nil?
		@html_container = params[:target]

		respond_to do |format|
			format.html # show.html.erb
			format.json { render json: @long_job }
			format.js   #{ render js: @long_job }
			format.text { render text: @long_job.id }
		end
	end

	# Takes 2 parameters and renders the result_view of LongJob
	# If the result view of LongJob is nil it renders the generic status.html.erb view
	# id:: LongJob ID
	# target:: HTML container name to put the result view in - default is "snupy_job_status"
	def result
		@long_job = LongJob.find(params[:id])
		params[:target] = "snupy_job_status" if params[:target].nil?
		@html_container = params[:target]

		if @long_job.result_view.nil? then #and !([LongJob::DONE, LongJob::STORED].include?(@long_job.status.to_s)) then
			# redirect_to action: "status"
			respond_to do |format|
				format.all { render "status" }# @long_job.result_view }
			end
		else
			if !([LongJob::DONE, LongJob::STORED].include?(@long_job.status.to_s)) then
				# in case its not done or failure
				respond_to do |format|
					format.all { render "status" }# @long_job.result_view }
				end
			else
				is_partial = @long_job.result_view.to_s.split("/")[-1][0] == "_"
				if is_partial then
					## If we have a partial and the request is a AJAX request, then we should only render the partial as a partial
					## if the request is not a AJAX request we should render the partial with the full header
					if request.xhr? then
						view = File.basename(@long_job.result_view).gsub(/^_/, "")
						location = File.dirname(@long_job.result_view)
						partial_file = location + "/" + view
						respond_to do |format|
							format.all { render partial: partial_file }
						end
					else
						respond_to do |format|
							format.all { render file: @long_job.result_view }
						end
					end
				else
					respond_to do |format|
						format.all { redirect_to @long_job.result_view }
					end
				end
			end
		end
	end

	# Clears all successful LongJobs from the database, that were cached.
	# This has to be called when something changes, that might change the result
	def clear_cache
		# jobs = LongJob.find_all_by_success(true)
		if current_user.is_admin then
			jobs = LongJob.where("status != 'FAILED' AND status != 'ENQUEUED'")
		else
			jobs = current_user.jobs
		end
		jobs.each do |job|
			job.destroy()
		end
		respond_to do |format|
			format.html { redirect_to long_jobs_url }
			format.json { render json: @long_jobs }
		end
	end

	#### IT SHOULD NO BE POSSIBLE TO CREATE JOBS THROUGH THE WEB INTERFACE
	# GET /long_jobs/new
	# GET /long_jobs/new.json
	def new
		@long_job = LongJob.new

		respond_to do |format|
			format.html # new.html.erb
			format.json { render json: @long_job }
		end
	end

	# GET /long_jobs/1/edit
	def edit
		@long_job = LongJob.find(params[:id])
	end

	# POST /long_jobs
	# POST /long_jobs.json
	def create
		@long_job = LongJob.new(params[:long_job])

		respond_to do |format|
			if @long_job.save
				format.html { redirect_to @long_job, notice: 'Long job was successfully created.' }
				format.json { render json: @long_job, status: :created, location: @long_job }
			else
				format.html { render action: "new" }
				format.json { render json: @long_job.errors, status: :unprocessable_entity }
			end
		end
	end

	# PUT /long_jobs/1
	# PUT /long_jobs/1.json
	def update
		@long_job = LongJob.find(params[:id])

		respond_to do |format|
			if @long_job.update_attributes(params[:long_job])
				format.html { redirect_to @long_job, notice: 'Long job was successfully updated.' }
				format.json { head :no_content }
			else
				format.html { render action: "edit" }
				format.json { render json: @long_job.errors, status: :unprocessable_entity }
			end
		end
	end

	# DELETE /long_jobs/1
	# DELETE /long_jobs/1.json
	def destroy
		@long_job = LongJob.find(params[:id])
		@long_job.destroy

		respond_to do |format|
			format.html { redirect_to long_jobs_url }
			format.json { head :no_content }
		end
	end

end
