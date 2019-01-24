##
# This class is used as a wrapper to show static pages.
# These pages can be changed, by changing the views.
class HomeController < ApplicationController
	
	before_filter(:only => [:api, :api_form]) { redirect_to root_path, alert: "You don't have permission to use the Query Interface." if current_user.api_key.nil? }
	
	include ApiHelper
	include ApplicationHelper
	
	def index
		@user = current_user
		#@vcf_files = @user.vcf_files
		#									.where(status: "DONE")
		#									.select(["vcf_files.id", "vcf_files.name", :sample_names, "vcf_files.contact"])
		#									.order('vcf_files.created_at DESC')
		#									.limit(64)
		#@incomplete_samples = @user.samples.reject(&:ready_to_query?)
		@experiments = @user.experiments.includes(:samples).order(:name)
		@data_overview = EntityGroup.dataset_summary(@user.owned(EntityGroup).order("entity_groups.updated_at DESC").limit(100).pluck(:id), false)
		@orphan_samples = current_user.visible(Sample).where(specimen_probe_id: nil).order("samples.updated_at DESC").limit(1000)
		@orphan_samples_total = current_user.visible(Sample).where(specimen_probe_id: nil).count
	end
	
	def about
	end
	
	def help
	end
	
	def citation
	end
	
	def aqua
		Aqua._reload() if Rails.env == "development"
		@annotations = Aqua.annotations
		@queries = Aqua.queries
		@aggregations = Aqua.aggregations
		@filters = []
		annot_order = Annotation.sort_by_requirements(@annotations.keys)
		@annotations = @annotations.map{|klass, config|
			{
				"Klass" => klass.name, 
				"Toolname" => config[:tool],
				"Name" => config[:name],
				"Execution Rank" => annot_order.index(klass),
				"Label" => config[:label], 
				"Input Format" => config[:input],
				"Output Format" => config[:output], 
				"Supported Organisms" => config[:organism].map(&:name).join(", "),
				"Supported Mutation types" => config[:supports].join(", "),
				"Required Models" => config[:model].map{|m|
					if m.is_a?(Array) # config[:model] can be an Array or a Hash - but when it is a Hash, then m will be [mode, [relations]]
						if m[1].is_a?(Array) then
							"#{m[0]} => <br>    #{m[1].map(&:name).join(" & ")}"
						else
							m.map{|ma| ma.name}.join(" & ")
						end
					else
						m.name
					end
				}.join("<br>").html_safe,
				"Satisfied?" => klass.satisfied?,
				# "Ready?" => klass.ready?,
				"Ready?" => klass.ready_machines.join(", "),
				"Required Annotations" => klass.get_requirements.map(&:name),
				"Required annotations available?" => klass.meets_all_requirements?,
				"Type" => klass.type,
				"Vcf Files" => ["OK", "PENDING", "INCOMPLETE", "REVOKED", "FAIL", "NOTAPPLICABLE"].map{|state| "#{state}: #{(klass.vcf_files(state) || []).size}"}.join(" | ")
			}
		}
		
		@queries = @queries.map{|type, klass2query|
			klass2query.map do |qklass, queries|
				queries.map do |qname, config|
					filters = qklass.filters[qname]
					filters = [] if filters.nil?
					filters.each do |f|
						collector_output = "METHOD NOT FOUND"
						if f.respond_to?(f.collection_method) then
							begin
								if f.public_methods(false).include?(f.collection_method.to_sym) then
									collector_output = f.send(f.collection_method, {}).first(64).map{|rec| 
										rec.pretty_inspect.gsub("  ", "&nbsp;&nbsp;").gsub("<", "&lt;").gsub(">", "&gt;").html_safe
									}.join("<br>").html_safe
									collector_output = "EMPTY" if collector_output == ""
								else
									collector_output = "" # not implemented for this filter.
								end
							rescue
								collector_output = "Could not determine automatically."
							end
						end
						fmethod = f.filter_method
						if fmethod.is_a?(Proc) then
							fmethod = "##{File.basename(fmethod.source_location.first)}:#{fmethod.source_location[1]}(#{fmethod.parameters.map{|x| x[1].to_s}.join(", ")})"
						end
						@filters << {
							"Klass" => f.class.name, 
							"Name" => f.name,
							"Label" => f.label,
							"Method" => fmethod,
							"Checked?" => f.checked,
							"Organisms" => f.organism.map(&:name).join(", "),
							"Applicable?" => f.applicable?, # f.organism.map{|o| "#{o.name}(#{f.applicable?(o.id)})"}.join(", "),
							"Requirements" => f.requirements,
							"Query" => "#{qklass.name}:#{qname}",
							"Collector" => f.collection_method.to_s,
							"Collector Output" => collector_output,
							"fkey" => f.fkey
						}
					end
					{
						"Klass" => qklass.name, 
						"Query" => qname,
						"Type"  => type,
						"Label" => config[:label],
						"Default" => config[:default],
						"Combine default" => config[:combine],
						"Tooltip" => config[:tooltip],
						"Supported Organisms" => config[:organism].map(&:name).join(", "),
						"Priority" => config[:priority],
						"Filter" => filters.map{|f|
							#f.class.name + "(#{f.name.to_s})[#{f.applicable?}]"
							f.fkey + "[#{f.applicable?}]"
						}.join("<br>").html_safe,
						"No. Filter" => filters.size,
						"qkey" => qklass.qkey(qname)
					}
				end
			end
		}.flatten
		
		@aggregations = @aggregations.map{|aklass, aggregations|
			aggregations.map do |aname, config|
				{
					"Klass" => aklass.name,
					"Name" => aname,
					"Applicable?" => aklass.applicable?(aname),
					"akey" => aklass.akey(aname)
				}.merge(config)
			end
		}.flatten
		
	end

	def show_log
		#@query_log = AquaQueryProcess.get_query_log(true)
		@query_log = EventLog.order("created_at DESC")
		@query_log = filter_collection @query_log, [:name, :identifier, :category], 100
		respond_to do |format|
			format.html # index.html.erb
			format.json {render json: @query_log}
		end
	end
	
	def show_log_details
		if params[:ids].size > 0
			@logs = EventLog.find(params[:ids]).map{|e|
				ret = (e.data || {}).dup
				ret = {data: ret} unless ret.is_a?(Hash)
				ret = {
						"event.name" => e.name,
						"event.identifier" => e.identifier,
						"event.duration" => e.duration,
						"event.error" => e.error,
						"event.category" => e.category
				}.merge(ret)
				ret
			}
			
			render_table(@logs,
			             title: "Log Data",
			             columns: (@logs.map(&:keys) || []).flatten.uniq
			             )
		else
			render text: "No entries selected", status: 500
		end
	end
	
	def destroy_log
		require_params  = {
			ids:                 params[:ids],
			"Are you sure?" => ["no", "yes"]
		}
		if determine_missing_params(require_params).size > 0 then
			render_table_details_params(require_params)
		else
			if (params["Are you sure?"] == "yes") then
				begin
					EventLog.where(id: params[:ids]).destroy_all
					render text: "[Success] Deleted #{params["ids"].size} records"
				rescue
					render text: "[Error] Could not delete log entries", status: 500
				end
			else
				render text: "[Abort] not doing anything."
			end
		end
		
		
	end

end
