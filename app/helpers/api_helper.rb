module ApiHelper
	def api
		if not current_user.is_admin?
			render text: ""
			return true
		end
		statement = get_statement(params)
		if statement.nil?
			render text: "No query given."
			return true
		end
		
		self.response.headers['Last-Modified'] = Time.now.ctime.to_s
		
		result = ApiKey.query(statement)
		#end
		respond_to do |format|
			format.text do
				self.response_body = create_response(result, params[:format], params)
			end
			format.csv do
				self.response_body = create_response(result, params[:format], params)
			end
			format.json do
				self.response_body = create_response(result, params[:format], params)
			end
			format.html do
				render partial: "home/table",  locals: {
						title: "Query Result",
						tableid: "api_result",
						content: result,
						footer: []
				}
				# self.response_body = create_response(result, params[:format])
				# render snupy table
			end
		end
		return true
	end
	
	def api_form
		begin
			statement = get_statement(params)
			@result = []
			if !statement.nil? and current_user.is_admin?
				counter = 0
				ApiKey.query(statement).each do |r|
					@result << r if counter < (params[:count].to_i || 5000)
					counter += 1
				end
			end
		rescue Mysql2::Error => e
			flash[:error] = e.message
		end
		
		self.response.headers['Last-Modified'] = Time.now.ctime.to_s
		
		respond_to do |format|
			format.html do
			end
		end
		return true
	end
	
private
	
	def get_statement(params)
		return params[:statement] || params["statement"] || params[:sql] || params["sql"] || params[:query] || params["query"]
	end
	
	def create_response(result, format, params)
		Enumerator.new do |y|
			header = nil
			header_printed = false
			y << "[" if format.to_s == "json"
			result.each do |r|
				header = r.keys if r.is_a?(Hash) and header.nil?
				y << case format.to_s
							 when "csv"
								 response_record_csv(r, header, !header_printed, params[:sep])
							 when "text"
								 response_record_text(r, header, !header_printed, params[:sep])
							 when "json"
								 response_record_json(r) + ",\n"
							 else
								 response_record_text(r, header, !header_printed, params[:sep]) + "\n"
						 end
				header_printed = true
			end
			y << "null]" if format.to_s == "json"
		end
	end
	
	def response_record_csv(record, header, print_header, sep = "\t")
		sep = "\t" if sep.nil?
		ret = []
		if !header.nil? then
			header.each do |h|
				ret << record[h]
			end
		else
			ret = record.to_a
		end
		ret = ret.to_csv({col_sep: sep, quote_char: '"', force_quotes: true})
		ret = header.to_csv({col_sep: sep, quote_char: '"', force_quotes: true}) + ret if print_header and !header.nil?
		ret
	end
	
	def response_record_text(record, header, print_header, sep = "\t")
		response_record_csv(record, header, print_header, sep)
	end
	
	def response_record_json(record)
		record.to_json
	end
	
end