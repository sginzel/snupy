# The Aqua Controller is not in the autoload path
# if you change anything here you need to restart the serveur
class AquaController < ApplicationController
	extend ActiveSupport::DescendantsTracker
	include ApplicationHelper
	include AquaParameterHelper
	# before_filter :access_required
	
	# list available annotations
	def listAnnotation
		tbl = Aqua.annotations.map{|klass, conf|
			([conf[:model].first] + conf[:model].first.descendants).reject(&:nil?).map{|mdl|
				{
					name: conf[:name],
					model: mdl.name,
					attributes: mdl.attribute_names.join(","),
					organism: conf[:organism].map{|o| "'#{o.name}'"}.join(","),
					ready: klass.ready?,
					machines: klass.ready_machines.join(",")
				}
			}
		}.flatten
		create_response(tbl)
	end
	
	# list available querys
	# INPUT: annotation
	def listQuery
		tbl = Aqua.queries.map{|type, queries|
			queries.map{|qklass, query_confs|
				query_confs.map{|qname, qconf|
					ret = {
						qkey: sprintf("%s:%s", qklass.name.underscore, qname),
						label: qconf[:label],
						organism: qconf[:organism].map{|o| "'#{o.name}'"}.join(","),
						default: qconf[:default],
						combine: qconf[:combine],
						type: qconf[:type]
					}
					ret[:default] = ret[:default].map{|x| "'#{x}'"}.join(",") if ret[:default].is_a?(Array)
					ret
				}
			}
		}
		create_response(tbl.flatten)
	end
	
	# list available filters
	# INPUT: query
	def listFilter
		if params[:qkey].nil? then
			queries = Query.all_filters
		else
			qklass = Aqua._get_klass(args[:qkey], Query)
			queries = {}
			queries[qklass] = Query.all_filters[qklass]
		end
		filters = queries.map{|qklass, queries|
			queries.map{|qname, filters|
				filters.map { |f|
					{
						fkey: f.fkey,
						qkey: qklass.qkey(qname), #sprintf("%s:%s", qklass.name.underscore, qname),
						label: f.label,
						organism: f.organism.map{|o| "'#{o.name}'"}.join(",")
					}
				}
			}
		}
		create_response(filters.flatten)
	end
	
	# list available aggregations
	def listAggregation
		tbl = Aqua.aggregations.map{|aklass, aconfs|
			aconfs.map{|aname, aconf|
				{
					akey: aklass.akey(aname),
					category: aconf[:category],
					colname: aconf[:colname],
					type: aconf[:type]
				}
			}
		}
		create_response(tbl.flatten)
	end
	
	# queries the annotations of an Annotation object
	# INPUT: model - Vep::Ensemnbl
	# INPUT: organism - OrganismId or Name
	# INPUT: varids - List of variation ids
	# INPUT: attributes - List of columns to select from model
	# INPUT: where - WHERE expression
	def annotation
		Aqua._init() if Rails.env == "development"
		begin
			use_stream = true
			deny_access = current_user.api_key.nil?
			if deny_access then
				return_status(status = 401, text = "Not accessible")
				return true
			end
			
			if !params[:model].nil? then
				# check if model string is valid
				model = params[:model]
				model = params[:model].first if model.is_a?(Array)
				valid = Aqua.annotations.keys.map(&:model).map(&:name) + Aqua.annotations.keys.map(&:model).map(&:descendants).flatten.map(&:name)
				if (!valid.include?(model))
					raise "no model given"
				end
				model = model.constantize
			else
				raise "no model given"
			end
			
			if !params[:organism].nil? then
				# check if model string is valid
				organism = params[:organism]
				organism = Organism.where("id = '#{organism}' OR name = '#{organism}'").first
			else
				raise "no organism given"
			end
			
			attrs = params[:attributes]
			attrs = params[:attributes].split(",") if params[:attributes].is_a?(String)
			attrs = model.attribute_names if params[:attributes].nil? or params[:attributes].to_s == ""
			attrs = ["variation_id", "organism_id"] + attrs
			varids = params[:varids]
			varids = varids.split(",") if varids.is_a?(String)
			scope = model
						.where(organism_id: organism.id)
						.where(variation_id: varids)
						.where(params[:where]).select(attrs.uniq)
			# we can use streaming to prevent MySQL from creating a temporary table. This should increase speed - but it does with the test data. Could be the overhead of allocating memory for result
			if Rails.env == "development" or use_stream then
				result = []
				Aqua.scope_to_array(scope){|r|
					result << r
				}
			else
				result = Aqua.scope_to_array(scope)
			end
			# tbl = Aqua.scope_to_array(scope)
			create_response(result)
			return
		rescue => e
			create_response({
								error: e.message,
								stacktrace: ((current_user.is_admin?)?(e.backtrace):(''))
							}, nil, nil, 500)
		end
	end
	
	# creates a hash structure required by query
	# based on filter keys provided by listFilter
	# INPUT: qkey => value
	# INPUT: fkeys
	# OUTPUT: hash that is used by query
	def build_query
		result = _build_query(params)
		create_response(result)
		return
	end
	
	# filter an input using a list of filters
	# INPUT: experiment
	# INPUT: [samples]
	# INPUT: query - as produced by build_query?format=json
	# INPUT: [qkey]
	# INPUT: [fkey]
	# OUTPUT: variation_call_ids
	# http://localhost:3000/aqua/query?format=json&experiment=1&fkey[]=filter_variation_call:vcdp&qkey[query_variation_call:read_depth][value]=30
	def query
		Aqua._init() if Rails.env == "development"
		# check if the current user has access to the experiment
		begin
			deny_access = false
			if !params[:experiment].nil? then
				if !current_user.is_admin then
					deny_access = !current_user.experiment_ids.include?(params[:experiment])
				end
			end
			if !(params[:samples] || params["samples"]).nil? then
				smpls = _accessable_samples(params[:samples] || params["samples"])
			else
				smpls = Experiment.find(params[:experiment]).sample_ids unless deny_access
			end
			deny_access = true if (smpls.nil? or smpls.size == 0)
			
			if deny_access then
				return_status(status = 401, text = "No accessible experiment or sample")
				return true
			end
			
			if !params[:qkey].nil? & !params[:fkey].nil? then
				query = _parse_query_keys(params)
			elsif !params[:query].nil?
				query = params[:query]
				query = query.first if query.is_a?(Array)
			else
				raise "no query given"
			end
			
			qparam = {
				queries: query,
				samples: smpls,
				"samples" => smpls,
				user: current_user,
				"user" => current_user,
				"experiment" => params[:experiment],
				experiment: params[:experiment]
			}
			aqp = AquaQueryProcess.new(params[:experiment])
			result = aqp.start(qparam, true)
			resp = {
				variation_call_ids: result,
				sample_ids: aqp.sample_ids,
				organism: aqp.organism.id
			}
			if (params[:sql].to_s == "1" || params["sql"].to_s == "1")
				resp[:sql] = aqp.sql_statements
			end
			
			# tbl = Aqua.scope_to_array(scope)
			create_response(resp)
			return
		rescue => e
			create_response({
				error: e.message,
				stacktrace: ((current_user.is_admin?)?(e.backtrace):(''))
			}, nil, nil, 500)
		end
	end
	
	# get aggregations for list of variants
	# INPUT: experiment
	# INPUT: [samples]
	# INPUT: [akey]
	# INPUT: [variation_call_ids]
	# OUTPUT: attributes
	# http://localhost:3000/aqua/aggregation?format=json&experiment=1
	# http://localhost:3000/aqua/aggregation?format=json&experiment=1&akey[]=aggregation_variation_call:variation_calls.sample_id&akey[]=aggregation_variation_call:variation_calls.variation_id&akey[]=aggregation_vep:vep_ensembl_symbol
	def aggregation
		Aqua._init() if Rails.env == "development"
		begin
			# check if the current user has access to the experiment
			deny_access = false
			if !params[:experiment].nil?
				if !current_user.is_admin then
					deny_access = !current_user.experiment_ids.include?(params[:experiment])
				end
			end
			if !(params[:samples] || params["samples"]).nil? then
				smpls = _accessable_samples(params[:samples] || params["samples"])
			else
				if (params[:experiment].nil?) then
					return_status(status = 401, text = "No Samples and not Experiment given.")
					return true
				end
				
				smpls = Experiment.find(params[:experiment]).sample_ids unless deny_access
			end
			deny_access = true if (smpls.nil? or smpls.size == 0)
			
			if deny_access then
				return_status(status = 401, text = "No accessible experiment or sample")
				return true
			end
			
			if !params[:key].nil? then
				aparams = _parse_query_keys(params)
				aparams[:samples] = smpls
			elsif !params[:aggregations].nil?
				aparams = params#[:aggregations]
				#aparams = aparams.first if aparams.is_a?(Array)
			else
				raise "no aggregation given"
			end
			aparams["user"] = current_user
			aparams[:user] = current_user
			#aparams = _parse_aggregation_keys(params)
			#aparams[:samples] = smpls
			vcids = params[:variation_call_ids]
			vcids = vcids.split(",") if vcids.is_a?(String)
			aap = AquaAggregationProcess.new(params[:experiment], vcids)
			tbl = aap.start_batch(aparams)
			# tbl = aap.start(aparams)
			create_response(tbl, "Experiment-#{params[:experiment]}", (tbl.first || {}).keys)
		rescue => e
			create_response({
								error: e.message,
								stacktrace: ((current_user.is_admin?)?(e.backtrace):(''))
							}, nil, nil,  500)
		end
		
	end
	
	# create a query process
	# INPUT: sample_ids
	# INPUT: filters
	# [INPUT]: job_name
	# OUTPUT: long_job_id
	# http://localhost:3000/aqua/queryJob?experiment=1&samples[]=1&format=json&qkey[query_variation_call:read_depth][value]=10&qkey[query_variation_call:read_depth][combine]=AND&fkey[]=filter_variation_call:vcdp
	def queryJob
		# check if the current user has access to the experiment
		deny_access = false
		if !current_user.is_admin then
			deny_access = !current_user.experiment_ids.include?(params[:experiment])
		end
		smpls = _accessable_samples(params[:samples] || params["samples"])
		deny_access = true if (smpls.nil? or smpls.size == 0)
		
		if deny_access
			return_status(status = 401, text = "No accessible experiment or sample")
			return true
		end
		
		@experiment = Experiment.find(params[:experiment])
		
		if !params[:qkey].nil? & !params[:fkey].nil? then
			query = _parse_query_keys(params)
		elsif !params[:query].nil?
			query = params[:query]
		else
			return_status(status = 400, text = "No query given")
			return true
		end
		
		qparam = {
			queries: query,
			samples: smpls
		}
		
		@long_job = LongJob.create_job({
													   title: (params[:job_name] || "queryJob#{Time.now}"),
													   handle: @experiment,
													   method: :query_aqua,
													   user: http_remote_user(),
													   queue: "snupy"
											   }, true, qparam)
		# make sure the job is redirected properly
		@long_job.result_view = aqua_experiment_url(
						@experiment,
						commit: "OK",
						commit_action: "load",
						jobname: @long_job.id,
						format: "html"
				)
		@long_job.save
		@experiment.long_jobs << @long_job unless @experiment.long_jobs.include?(@long_job)
		create_response(@long_job.id)
	end
	
	# get result of a job. Returns nil if job has not finished
	# INPUT: long_job
	# OUTPUT: list of variation_call_ids and variation_calls or nil
	# http://localhost:3000/aqua/getJob?long_job=11&format=json
	def getJob
		lj = LongJob.find(params[:long_job])
		if lj.nil? then
			return_status(status = 400, text = "LongJob #{params[:long_job]} does not exist.")
			return true
		end
		experiment = Experiment.joins(:long_jobs).where("long_jobs.id" => lj).first
		deny_access = false
		if !current_user.is_admin then
			deny_access = !current_user.experiment_ids.include?(params[:experiment])
		end
		
		if deny_access
			return_status(status = 401, text = "Experiment not accessible.")
			return true
		end
		
		if lj.success then
			if !lj.result_obj.is_a?(AquaResult) then
				return_status(status = 400, text = "LongJob #{params[:long_job]} cannot be loaded.")
				return true
			end
			ret = {variation_call_ids: lj.result_obj.load()}
		else
			ret = lj.status
		end
		create_response(ret, )
	end
	
	
	def query_collection()
		qklass = Aqua._get_klass(params["qklass"], Query)
		params[:user] = current_user
		params["user"] = current_user
		collection = []
		if !qklass.nil? then
			collection = qklass.get_collection(qklass, params["qname"].to_sym, params)
		end	
		respond_to do |format|
  		format.html {
  			render partial: "experiments/aqua/queries/filter_collection", locals:{ list: collection }
  		}
  	end
		return true if 1 == 1
		# render text: collection.to_json
		# columns = collection.map{|rec|rec.keys}.flatten.uniq
		render partial: "home/table", locals: {
				title: "Query Collection", 
				tableid: "query_collection",
				# header: (columns || []), 
				content: collection,
				footer: []
			}
		
		# head :ok
	end
	
	def query_details()
		user = current_user()
		experiment = Experiment.find(params["ajax_params"][:experiment])
		samples = Sample.find(params["ajax_params"][:samples])
		organism = experiment.organism
		
		vcids = params[:variation_id]
		vcids = vcids.to_s.split(" | ").flatten
		# variation_calls = VariationCall.find(vcids)
		
		# variation = Variation.find(params[:variation_id])
		variation = Variation.joins(:variation_calls).where("variation_calls.id" => vcids)
		vids = variation.pluck("variations.id")
		
		group_by_variation_id = params["ajax_params"][:group].to_s == "true"
		tools = params["ajax_params"][:tools].to_s
		
		# if user.is_admin then
		# 	mysamples = Sample.joins(:vcf_file).where("vcf_files.organism_id" => experiment.organism.id).pluck("samples.id")
		# else
		# 	mysamples = Sample.joins(:vcf_file).joins(:users).where("users.id" => user.id).where("vcf_files.organism_id" => experiment.organism.id).pluck("samples.id")
		# end
		mysamples = user
								.reviewable(Sample)
								.joins(:vcf_file)
								.where("vcf_files.organism_id" => experiment.organism_id)
								.pluck("samples.id")
		expsamples = experiment.sample_ids
		
		# find distribution of snv in this experiment and other samples
		selected_samples = Sample.find(params["ajax_params"][:samples]).map(&:id)
		
		sample2var = []
		vc2smpl = Aqua.scope_to_array(VariationCall.joins(:sample).where(variation_id: vids).where(sample_id: mysamples + expsamples).select(["samples.patient", "variation_calls.sample_id", "samples.name"]))
		sample2var << {
			"Description" => "Variants in database",
			"#Patients" => vc2smpl.map{|rec| rec["patient"]}.uniq.size,
			"#Samples" => vc2smpl.map{|rec| rec["sample_id"]}.uniq.size,
			"#Patients in project" => vc2smpl.select{|vc| expsamples.include?(vc["sample_id"])}.map{|rec| rec["patient"]}.uniq.size,
			"#Samples in project" => vc2smpl.select{|vc| expsamples.include?(vc["sample_id"])}.map{|rec| rec["sample_id"]}.uniq.size,
			"Affected Patients in project" => vc2smpl.select{|vc| expsamples.include?(vc["sample_id"])}.map{|rec| rec["patient"]}.uniq.sort.join(" | "),
			"Affected Samples in project" => vc2smpl.select{|vc| expsamples.include?(vc["sample_id"])}.map{|rec| rec["name"]}.uniq.sort.join(" | ")
		}
		
		# find all data for each AQuA Annotation tool that is related to the variation
		data = {}
		data["Variation Calls in your samples (first 100)"] = Aqua.scope_to_array(VariationCall
																	.joins(:sample)
																	.where("sample_id" => [mysamples + expsamples])
																	.where("variation_calls.variation_id" => vids)
																	.limit(100)).uniq
		Aqua.annotations.each do |model, config|
			next unless tools == "all" or config[:label].to_s == tools.to_s
			next if config[:supports].include?(:none)
			# base_scope = Aqua.base_scope(experiments.map(&:id), 
			variation_scope = Aqua.base_scope(experiment.id,
												sample_ids = nil, 
												varcall_cols = false, 
												sample_cols = false, 
												experiment_cols = false, 
												variation_cols = true).where("variation_calls.variation_id" => vids)
			
			if config[:model].is_a?(Hash) then
				# add the base model and its attributes
				variation_scope = Aqua.add_required(variation_scope, true, organism.id, [config[:model].keys.first])
			end
			variation_scope = Aqua.add_required(variation_scope, true, organism.id, config[:model])
			variation_scope = variation_scope.select("variation_calls.variation_id AS `variation_calls.variation_id`")
			# data[config[:label]] = SnupyAgain::Utils.scope_to_array(variation_scope)
			data[config[:label]] = Aqua.scope_to_array(variation_scope, true).uniq
		end
		render partial: "experiments/aqua/details", locals: {
			experiment: experiment,
			sample2var: sample2var,
			samples: samples,
			variation: variation,
			aqua_data: data,
			group_by_variation_id: group_by_variation_id
		}
	end
	
private
	
	def return_status(status = 200, text = nil)
		respond_to do |format|
			format.html { render :status => status, :text => text } 
			format.csv  { render :status => status, :text => text}
			format.json { render :status => status, :text => text}
			format.yaml { render :status => status, :text => text}
		end
	end
	
	#def create_response(tbl, formats = [:html, :csv, :json, :yaml], name = nil, columns = nil, status = 200)
	def create_response(tbl, name = nil, columns = nil, status = 200)
		tbl = [tbl] unless tbl.is_a?(Array)
		tbl = [{message: "Empty"}] if tbl.nil?
		#formats = [formats] unless formats.is_a?(Array)
		if tbl.first.is_a?(Hash) and columns.nil? then
			columns = (tbl.first || {}).keys if columns.nil?
		end
		#if !formats.map(&:to_s).include?(self.request.format.symbol.to_s) then
		#	return_status(status = 400, text = "#{self.request.format.symbol} not supported you ass")
		#	return true
		#end
		respond_to do |format|
			format.html{
				render_table(tbl,
					title: name,
					columns: columns,
					select_type: :none,
				)
			} #if formats.include?(:html)
			
			format.csv{
				render_csv(tbl, name, columns)
			} #if formats.include?(:csv)
			
			format.json { render json: tbl.to_json, status: status } #if formats.include?(:json)
			#format.yaml { send_data tbl.to_yaml, :content_type => 'text/yaml', status: status } #if formats.include?(:yaml)
		end
	end
	
	def render_csv(tbl, name=nil, columns = [])
		tbl = [tbl] unless tbl.is_a?(Array)
		tbl = [{message: "Empty"}] if tbl.nil?
		if tbl.first.is_a?(Hash) and columns.nil? then
			columns = (tbl.first || {}).keys if columns.nil?
		end
		filename = ((name.nil?)?(tbl.hash):(name)).to_s + ".csv"
		if request.env['HTTP_USER_AGENT'] =~ /msie/i
			headers['Pragma'] = 'public'
			headers["Content-type"] = "text/plain"
			headers['Cache-Control'] = 'no-cache, must-revalidate, post-check=0, pre-check=0'
			headers['Content-Disposition'] = "attachment; filename=\"#{filename}\""
			headers['Expires'] = "0"
		else
			# headers["Content-Type"] ||= 'text/tab-separated-values'
			headers["Content-Disposition"] = "attachment; filename=\"#{filename}\""
			headers["Content-Type"] ||= 'text/plain'
			headers["Content-Disposition"] = "inline"
			
		end
		render_table(tbl,
							 title: "Annotations",
							 format: "csv",
					 		 select_type: :none,
							 columns: columns
		)
	end
	
	def _accessable_samples(smplids)
		smplids = [smplids] unless smplids.is_a?(Array)
		current_user.visible(Sample).pluck("samples.id") & smplids
	end
	
	# TODO: Fix list of accessible samples using the new schema
	def _accessable_samples_old(smplids)
		if smplids.is_a?(Hash) then
			smplids = (smplids[:samples] || smplids["samples"]) || (smplids[:sample_id] || smplids["sample_id"]) 
		end
		smplids = [smplids] unless smplids.is_a?(Array)
		if !current_user.is_admin then
			smplids = smplids & current_user.sample_ids
		end
		if !smplids.nil? and smplids.size > 0
			smplids = Sample.where(id: smplids).pluck(:id)
		end
		smplids
	end

	
end