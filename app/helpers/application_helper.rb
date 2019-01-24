# == Description
# Helper Module
module ApplicationHelper
	include SimpleStatisticHelper
	## This is a generic method to render a single table from a mostly arbitrary object
	## It accepts many parameters that are yet to be described
	## TODO Document this method!!!
	## colors: {colname: value, colname2: value1}
	##         Value can be, a Hash, a lambda, a Symbol, a String, an Array, or a Interpolate::Points as returned by create_color_gradient
	##         Hash: Maps between the cell text and a color. Needs to provide all colors and a valid default color.
	##         lambda: The lambda can compute a color from the celltext
	##         Symbol: Right now only :bool and :boolean are supported which map palegreen and salmon to true/false
	##         String: A color for all cells of the given column
	##         Array: Can be used to explicitly color the rows. Does probably not work properly when using group_by. Array is recycled as needed
	##         Interpolate::Points: Calls .at(cell_text.to_f) to show a color gradient.
	##         Warning: Using color breaks the big cell feature and cells are not collapsed anymore.
	def render_table(collection, opts = {}, &block)
		
		begin
			collection = collection.all if collection.is_a?(ActiveRecord::Relation)
		rescue => e
			eid = e.hash.to_i.abs.to_s(16)
			logger.fatal "[#{Time.now}##{eid}] ERROR in data retrieval for #{opts}"
			logger.fatal "[#{Time.now}##{eid}] PARAMS \n[##{eid}] #{params.pretty_inspect.split("\n").join("\n[##{eid}] ")}"
			logger.fatal "[#{Time.now}##{eid}] " + e.message
			logger.fatal "[#{Time.now}##{eid}] "	 + e.backtrace.join("\n[##{eid}] ")
			logger.fatal "[#{Time.now}##{eid}] SQLERROR " + collection.to_sql
			logger.fatal "[#{Time.now}##{eid}] END of ERROR ##{eid}"
			collection = []
			flash[:alert] = "Something went wrong when retrieving the data for #{opts[:id] || 'unknown_table'} (ErrorRefID: ##{eid})"
		end
		collection = [collection] if not collection.is_a?(Array)
		
		opts = {
			title: "Table",
			columns: get_attributes(collection),
			#column_order: [".*"],
			column_order: nil,
			id: "snupytable_#{Time.now.to_f.to_s.gsub(".", "")}",
			is_active_record_collection: collection.first.is_a?(ActiveRecord::Base),
			base_model: collection.first.class,
			details_path: nil,
			selected: [],
			detail_params: {},
			path_method: nil,
			css: {},
			format: "html",
			selectbox: true,
			groupby: [],
			groupconcat: {},
			collapsecell: 150,
			colors: {},
			record_colors: {},
			idcol: :id,
			autolink_id: true,
			show: true,
			select_type: :checkbox,
			table_class: "snupytable",
			actions: {}
		}.merge(opts)
		
		opts[:colors] = opts[:color] if !opts[:color].nil? and opts[:colors].size == 0
		opts[:record_colors] = opts[:record_color] if opts[:record_colors].size == 0 and !opts[:record_color].nil?

		columns = (opts[:columns] || get_attributes(collection))
		column_order = (opts[:column_order] || columns.uniq)
		title   = opts[:title]
		tableid = opts[:id].to_s
		tablename = tableid.dup
		tableid = tableid.gsub(/[^A-Za-z0-9:._-]/, "") # make sure tblid is a valid - https://www.w3.org/TR/html4/types.html#type-name
		is_active_record_collection = opts[:is_active_record_collection]
		base_model = opts[:base_model]
		details_path = opts[:details_path]
		detail_params = opts[:detail_params]
		selected = opts[:selected]
		path_method = opts[:path_method]
		groupby = opts[:groupby] # [bycol1, bycol2, bycol3]
		groupconcat = opts[:groupconcat] # {[col1, col2] => ["format_string", "new_colname"]}
		collapsecell = opts[:collapsecell]
		colors = opts[:colors]
		record_colors = opts[:record_colors]
		idcol = opts[:idcol]
		autolink_id = opts[:autolink_id]
		select_type = (opts[:select_type] || :checkbox)
		table_class = opts[:table_class]
		
		selected = [] if selected.nil?
		selected = [selected] unless selected.is_a?(Array)
		
		selected = selected.map{|s|
			if (s.is_a?(ActiveRecord::Base)) then
				s.id
			else
				s
			end
		}
		
		if (is_active_record_collection or (!base_model.nil? && base_model.ancestors.include?(ActiveRecord::Base))) then
			base_model_name = base_model.to_s.gsub(/([A-Z])/, "_\\1").gsub(/^_/,"").downcase
		else
			base_model_name = nil
		end

		if (collection.size == 0) then
			return render partial: "home/table", locals: {
				title: title, 
				tableid: tableid,
				header: (columns || []), 
				content: [],
				footer: []
			}
		end

		## if we have a active record collection convert it to an array of hashes
		## this doubles the memory efforts, but saves us from problems with ActiveRecord
		## when adding cusom columns
		raw_collection = []
		if is_active_record_collection then
			new_collection = []
			collection.each_with_index do |rec, i|
				## get a hash from the record and cast the keys to be symbols
				new_rec = Hash[rec.attributes.dup.map{|k,v| [k.to_sym, v]}]
				new_collection << new_rec
			end
			raw_collection = collection
			collection = new_collection
		end
		## at this point the collection is not a active record collection anymore, even if it was so intially
		is_active_record_collection = false
		
		# if a block is given with the call to render_table we call the block for every record.
		# This is utilized to add links for example
		if block_given? then
			added_columns = []
			removed_columns = []
			(0...collection.size).each do |i|
				next if collection[i].nil?
				keys_before = collection[i].keys 
				collection[i] = yield [collection[i].dup, raw_collection[i]]
				keys_after = collection[i].keys
				new_keys = keys_after - keys_before
				removed_keys = keys_before - keys_after
				added_columns << new_keys
				removed_columns << removed_keys
			end
			added_columns = added_columns.flatten.uniq
			removed_columns = removed_columns.flatten.uniq
			columns += added_columns
			columns.reject!{|c| removed_columns.include?(c.to_sym) || removed_columns.include?(c)}
		end


		## add path to show a record if there is a path associated with the model
		if ( !base_model_name.nil? && opts[:show]) then
			# Rails.application.routes.url_helpers.send(path_name)
			if path_method.nil? then
				path_name = "#{base_model_name}_path"
			else
				path_name = path_method
			end
			if Rails.application.routes.url_helpers.respond_to?(path_name.to_sym) then
				collection.each do |rec|
					begin 
						rec["Show"] = ActionController::Base.helpers.link_to("Show", Rails.application.routes.url_helpers.send(path_name.to_sym, rec[idcol]))
					rescue ActionController::RoutingError
						rec["Show"] = "Cannot link to show"
					end
					# rec["  "] = ActionController::Base.helpers.link_to("Delete", Rails.application.routes.url_helpers.send(path_name.to_sym, rec.id), method: :delete, data: { confirm: 'Are you sure?' })
				end
				columns << "Show"
				column_order.insert(-1," ")
			end
		end
		
		if details_path.nil? then
			details_path = "detail_#{base_model_name}_path" 
			if (Rails.application.routes.url_helpers.respond_to?(details_path.to_sym)) then
				path_template = Rails.application.routes.url_helpers.send(details_path.to_sym, 0, format: "html")
				path_template.gsub!("0", ":id")
			else
				path_template = nil
			end
		else
			path_template = details_path
		end
		## add selection boxes to select specific entries
		if !collection.first.nil? &&
			(!opts[:selectbox].nil? && opts[:selectbox]) &&
			(collection.first.keys.include?(idcol) or collection.first.keys.include?(idcol.to_s)) &&
			select_type != :none
			then
			collection.each{|rec|
				if select_type == :checkbox or select_type == :checkboxes or select_type == :multiple or select_type == :select then
					rec["Select"] = ActionController::Base.helpers.check_box_tag "#{tablename}[]", # name
																				 (rec[idcol] || rec[idcol.to_s]).to_s, # value
																				 selected.map(&:to_s).include?(rec[idcol].to_s), # selected 
																				 id: "#{tableid}_#{(rec[idcol] || rec[idcol.to_s])}_template".gsub(/[^A-Za-z0-9:._-]/, ""), # id
																				 class: "snupy_table_selectbox" # css class
				elsif select_type == :option or select_type == :options or select_type == :radio or select_type == :single then
					rec["Select"] = ActionController::Base.helpers.radio_button_tag "#{tablename}[]", # name
																				 (rec[idcol] || rec[idcol.to_s]).to_s, # value
																				 selected.map(&:to_s).include?(rec[idcol].to_s), # selected 
																				 id: "#{tableid}_#{(rec[idcol] || rec[idcol.to_s])}_template".gsub(/[^A-Za-z0-9:._-]/, ""), # id
																				 class: "snupy_table_selectbox" # css class
				else
					rec["Select"] = "no selection available"
				end
			}
			columns << "Select"
			column_order.insert(0,"Select")
		end
		
		## group/collapse the rows of collection according to the given colnames
		if groupby.size > 0 then
			if groupconcat.size > 0 then
				groupconcat.each do |colname, fmt_and_cols|
					# d colname
					# d fmt_and_cols.class
					if fmt_and_cols.is_a?(Array) then
						fmt = fmt_and_cols[0]
						cols = fmt_and_cols[1]
						collection.each do |rec|
							vals = cols.collect{|c| rec[c]}
							rec[colname] = sprintf(fmt, *vals)
						end
					elsif fmt_and_cols.is_a?(Proc)
						collection.each do |rec|
							rec[colname] = fmt_and_cols.call(rec) 
						end
					else
						collection.each do |rec|
							rec[colname] = "cannot process this entry"
						end
					end
					columns << colname unless columns.include?(colname)
				end
			end
			rowlookup = {}
			collection.each do |rec|
				key = groupby.map{|c| rec[c]}.join(":")
				if rowlookup[key].nil? then
					rowlookup[key] = rec
				else
					rec.each do |col, val|
						rowlookup[key][col] = [rowlookup[key][col], val].flatten.uniq 
					end
				end
			end
			
			rowlookup.keys.each do |key|
				rowlookup[key].keys.each do |col|
					rowlookup[key][col] = rowlookup[key][col].reject{|x| x.nil? }.join(", ") if rowlookup[key][col].is_a?(Array)
				end
			end
			collection = rowlookup.values
		end
		
		
		## sort the columns by the given mask
		# column_order = ["Select", ".*", " "]
		## find the indexes that either match the columns exactly
		## or match the regular expression
		column_order_idx = columns.map{|c|
			if (column_order.any?{|co| co == c}) then
				column_order.index(c)
			else
				column_order.index{|co|
					!(Regexp.new(co.to_s) =~ c).nil?
				}
			end
		}
		## create a sort index / map, so we can easily map column names to the indexes
		## to which they match in the column_order array
		sort_index = Hash[columns.each_with_index.map{|colname, col_idx| [colname, column_order_idx[col_idx]] }]
		## sort the columns by their index to which they match in the column_order array 
		## append to the end, if
		columns.sort!{|x,y|
			ret = 0
			## in case one column doesnt match an order rule
			if sort_index[x].nil? or sort_index[y].nil? then
				ret = 1 if sort_index[x].nil?
				ret = -1 if sort_index[y].nil?
				## if both dont match a rule the original order should be used
				ret = columns.index(x) <=> columns.index(y) if sort_index[y].nil? and sort_index[x].nil?
			else
				## if both column names match the same column order rule then
				## the order in the column array should be used
				if sort_index[x] == sort_index[y] then
					ret = columns.index(x) <=> columns.index(y)
				else
					ret = sort_index[x] <=> sort_index[y]
				end
			end
			ret
		}

		## parse the columns for _id and _ids fields and link those fields to the corresponding models
		if autolink_id then
			columns.select{|c| c.to_s =~ /(_id$)|(_ids$)/}.each do |id|
				modelname = id.to_s.gsub(/(_id$)|(_ids$)/, "")
				modelpath = "#{modelname}_path".to_sym
				if (Rails.application.routes.url_helpers.respond_to?(modelpath)) then
					collection.each do |rec|
						next if rec.nil?
						id = id.to_sym if rec[id].nil?
						next if rec[id].nil?
						rec[id] = link_to rec[id], Rails.application.routes.url_helpers.send(modelpath, rec[id], format: "html")
					end
				end
			end
		end
		
		#render partial: "home/table.#{opts[:format]}.erb", locals: { # deprecation warning
		render partial: "home/table", locals: {
			title: title, 
			tableid: tableid,
			header: (columns.uniq || []), 
			content: collection,
			model: base_model, 
			path_template: path_template,
			ajax_params: detail_params,
			collapsecell: collapsecell,
			footer: [],
			colors: colors,
			record_colors: record_colors,
			idcol: idcol,
			table_class: table_class
		}.reverse_merge(opts)
		
	end
	
	def render_combobox (collection, opts = {}, &block)

		collection = collection.all if collection.is_a?(ActiveRecord::Relation)
		collection = [collection] if not collection.is_a?(Array)
		
		timestamp = Time.now.to_f.to_s.gsub(".", "")
		opts = {
			label: "Select",
			id: "snupycombobox_#{timestamp}",
			#name: "snupycombobox_#{timestamp}",
			simple: false,
			selected: nil,
			labelattr: :id,
			valueattr: :id,
			validonly: true,
			allowempty: false,
			include_blank: false,
			onchange: nil
		}.merge(opts)
		
		options = collection.map{|rec|
			if rec.is_a?(Array) then
				[rec[0], rec[1]]
			elsif !(rec.is_a?(Hash) || rec.is_a?(ActiveRecord::Base)) then
				# {label: rec, value: rec}
				[rec, rec]
			else
				#{label: rec[opts[:labelattr]], value: rec[opts[:valueattr]]}
				[rec[opts[:labelattr]], (rec[opts[:valueattr]] || rec[opts[:idattr]])]
			end
		}
		options = ([["", ""]] + options).uniq if opts[:include_blank]
		
		render partial: "home/combobox", locals: {
			comboboxclass: (opts[:simple] || !opts[:onchange].nil?)?"snupycombobox_simple":"snupycombobox",
			label: opts[:label], 
			boxid: opts[:id],
			selectoptions: options.uniq,
			validonly: opts[:validonly],
			allowempty: opts[:allowempty],
			selected: opts[:selected],
			onchange: opts[:onchange]
		}.reverse_merge(opts)
	end
	
	#' This method can render a table with attributes of a Class which can then be used
	#' to mass-create objects
	def render_form_table(klass, opts = {}, &block)

		opts = {
			title: "Form Table",
			count: 10,
			id: "form_table_#{Time.now.to_f.to_s.gsub(".", "")}",
			attributes: Hash.new({type: :string}),
			klass: klass
		}.merge(opts)
		
		
		render partial: "home/form_table", locals: {
		}.reverse_merge(opts)
	end
	
	def determine_missing_params(required_params)
		missing_params = {}
		# parsedrequired = Rack::Utils.parse_nested_query(required_params.to_query)
		required_params.each do |k,v|
			# if k is a simple ID and doesnt contain an array or hash
			if !k.to_s.index("[") then
				missing_params[k] = v if params[k].nil? or params[k].to_s == ""
			else
				# if an array or hash is required we only check if any available key in the submitted
				# parameters look like it belongs to the required key. 
				missing_params[k] = v unless params.keys.any?{|pk| k.to_s.index(pk.to_s)}
			end
		end
		missing_params
	end
	
	def render_table_details_params(required_params, opts = {}, &block)
		opts = {
			label: ""
		}.merge(opts)
		missing_params = determine_missing_params(required_params)
		present_params = {}
		required_params.each do |k,v|
			present_params[k] = params[k] unless params[k].nil? or params[k].to_s == ""
		end
		if missing_params.size > 0 then
			respond_to do |format|
				format.html { 
					render partial: "home/table_details_params", locals:{
						label: opts[:label],
						fields: missing_params,
						resource: url_for(action: params[:action]),
						otherparams: present_params
					}
				}
			end
		end
		
	end
	
	def get_input_table(template, baseid)
		ret = {}
		template.each do |colname, attrs|
			fieldname = "#{baseid}[#{colname}]"
			if attrs == :number
				ret[colname.to_s.humanize] = (ActionController::Base.helpers.number_field_tag fieldname, "")
			elsif attrs == :string
				ret[colname.to_s.humanize] = (ActionController::Base.helpers.text_field_tag fieldname, "")
			elsif attrs.is_a?(Array)
				x = attrs
				if !x.first.is_a?(Array)
					x = x.map{|y| [y,y]}
				end
				x = ([["", ""]] + x).uniq
				ret[colname.to_s.humanize] = ActionController::Base.helpers.select_tag fieldname, 
				ActionController::Base.helpers.options_for_select(x), {
					class: "snupycombobox",
					id: fieldname,
					name: fieldname
					}
			end
		end
		ret
	end
	
	# If using RGB color space use balance_factor = 100
	def create_color_gradient(values = [0, 1], colors = [Color::RGB::Red.to_hsl, Color::RGB::Green.to_hsl], balance_factor = 1, use_hsl = true)
		points = {}
		raise "Values and colors have to be the same length > 1" if (values.length != colors.length) or values.length < 1
		values.each_with_index{|v, i|
			colval = colors[i]
			if colval.is_a?(String)
				if (use_hsl)
					colval = Color::RGB.by_name(colval).to_hsl
				else
					colval = Color::RGB.by_name(colval)
				end
			end
			points[v] = colval
		}
		gradient = Interpolate::Points.new(points)
		gradient.blend_with {|color, other, balance|
			# col = Color::HSL.from_fraction(color[0], color[1], color[2])
			# othrcol = Color::HSL.from_fraction(other[0], other[1], other[2])
			# col.mix_with(othrcol , balance * 100.0)
			color.mix_with(other , balance * balance_factor)
		}
		gradient
	end 
	
	def get_color(value, gradient)
		gradiant.at(value).html
	end
	
	def give_help(controller, action)
		# check if controller knows help for the action
		if (File.exists?(File.join("app", "views", controller, "_help_#{action}.html.erb"))) then
			template = "#{controller}/help_#{action}"
			render partial: "home/help", locals:{controller: controller, action: action, template: template}
		else
			""
		end
	end
	
private
 
	def get_attributes(collection)
		attributes = nil
		attributes_to_ignore = [/.+\.id$/, /.*\.created_at$/, /.*\.updated_at$/]
		if collection.first.is_a?(ActiveRecord::Base) then
				attributes = collection.first.class.accessible_attributes.to_a.reject{|a| a == ""}
				attributes = (attributes | collection.first.attributes.keys)
		elsif collection.first.is_a?(Hash) then
			attributes = collection.first.keys
		else
			attributes = []
		end
		attributes.reject{|a| 
			attributes_to_ignore.any?{|ignore_pattern| 
				a.to_s =~ ignore_pattern
			}
		}.uniq
	end
	
end
