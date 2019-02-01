class ReportsController < ApplicationController
	include ApplicationHelper
	
	# GET /reports
	# GET /reports.json
	def index
		@reports = current_user.visible(Report)
		@reports = filter_collection @reports, [:name, :identifier, :xref_klass, :xref_id, :institution_id, :id], 100
		@reports = @reports.select(%w(name identifier mime_type type valid_until xref_id xref_klass id))
		
		respond_to do |format|
			format.html # index.html.erb
			format.json {render json: @reports}
		end
	end
	
	# GET /reports/1
	# GET /reports/1.json
	def show
		@report = current_user.visible(Report).find(params[:id])
		
		respond_to do |format|
			format.html # show.html.erb
			format.json {render json: @report}
		end
	end
	
	# GET /reports/new
	# GET /reports/new.json
	def new
		@report = Report.new
		@report.user = current_user
		@report.institution = Institution.new
		
		respond_to do |format|
			format.html # new.html.erb
			format.json {render json: @report}
		end
	end
	
	# GET /reports/1/edit
	def edit
		@report = Report.find(params[:id])
	end
	
	# POST /reports
	# POST /reports.json
	def create
		@report = Report.new(params[:report])
		@report.user_id = current_user.id
		@report.mime_type = retrieve_mime_type(params[:report])
		@report.content = retrieve_content(params[:report])

		
		respond_to do |format|
			if @report.save
				format.html {redirect_to @report, notice: 'Report was successfully created.'}
				format.json {render json: @report, status: :created, location: @report}
			else
				format.html {render action: "new"}
				format.json {render json: @report.errors, status: :unprocessable_entity}
			end
		end
	end
	
	# PUT /reports/1
	# PUT /reports/1.json
	def update
		@report = Report.find(params[:id])
		@report.user_id = current_user.id
		@report.mime_type = retrieve_mime_type(params[:report])
		@report.content = retrieve_content(params[:report])
		
		respond_to do |format|
			if @report.update_attributes(params[:report])
				format.html {redirect_to @report, notice: 'Report was successfully updated.'}
				format.json {head :no_content}
			else
				format.html {render action: "edit"}
				format.json {render json: @report.errors, status: :unprocessable_entity}
			end
		end
	end
	
	# DELETE /reports/1
	# DELETE /reports/1.json
	def destroy
		begin
			@report = current_user.editable.find(params[:id])
			@report.destroy
		rescue ActiveRecord::RecordNotFound
			flash[:alert] = "#{params[:id]} does not exist"
			@report = Report.new()
		end
		
		respond_to do |format|
			format.html {redirect_to reports_url}
			format.json {head :no_content}
		end
	end

	def download
		@report = current_user.visible(Report).find(params[:id])
		send_data @report.content, filename: @report.name, type: @report.mime_type
	end
	
private
	# returns the content from the uploaded file
	def retrieve_content(params)
		params.delete("content_upload").read
	end
	
	def retrieve_mime_type(params)
		mime = params.delete("mime_type")
		if mime == "auto" then
			params["content_upload"].content_type
		else
			mime
		end
	end
end
