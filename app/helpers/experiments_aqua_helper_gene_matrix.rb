module ExperimentsAquaHelperGeneMatrix
	include ApplicationHelper
	
	def get_aqua_models()
		aqua_models     = Aqua.annotations.values.flatten.map {|a|
			mdl = a[:model].first
			if mdl.descendants.size == 0 then
				mdl
			else
				mdl.descendants
			end
		}.flatten
		aqua_models
	end
	
	# convert a array of [{colname: col1, rowname: row1, value: val}] to
	# [{row1: row1, col1: val}]
	def long_to_wide(matrix, column, row, value)
		widemat = []
		columns = matrix.map{|rec| rec[column].to_s}.uniq.sort
		rows = matrix.map{|rec| rec[row].to_s}.uniq.sort
		# initilize matrix
		widemat = {}
		rows.each do |r|
			widemat[r] ||= {id: r, "#{row}" => r}
			columns.each do |col|
				widemat[r][col] = []
			end
		end
		# return widemat.values.flatten
		matrix.each do |rec|
			r = rec[row].to_s
			c = rec[column].to_s
			widemat[r][c] << rec[value]
		end
		widemat.values.flatten
	end
	
	def get_colors_from_matrix(matrix, cols_to_exclude = [])
		colors = {}
		matrix.each do |rec|
			rec.keys.each do |k|
				next if k.to_s == "id" or cols_to_exclude.include?(k)
			end
		end
	end
	
	def add_margin_sums(matrix, cols_to_exclude = [])
		rowsums = {}
		colsums = {}
		matrix.each_with_index do |rec, i|
			rec.keys.each do |k|
				next if k.to_s == "id" or cols_to_exclude.include?(k)
			end
		end
		matrix << colsums
		matrix
	end
	
	def get_matrix(params, aggregation = "count", what = "presence", verbose = false)
		ids = params[:ids]
		if ids.is_a?(Array) then
			ids = ids.map {|id| id.split(" | ")}.flatten
		end
		grouping_models = [EntityGroup, Entity, SpecimenProbe, Sample].reverse
		
		aqua_model  = get_aqua_models.select {|a| a.name == params[:annotation]}.first
		group_model = grouping_models.select {|a| a.name == params[:column_attribute]}.first
		experiment  = Experiment.find(params[:experiment])
		organism_id = experiment.organism.id
		if params[:selected_samples] == 'All samples in Project' then
			smplids = experiment.sample_ids
		else
			smplids = params[:samples]
		end
		# make sure that the variation call ids contain the samples we want to see.
		ids = VariationCall
				  .where(variation_id:
							 VariationCall.where(id: ids).where(sample_id: smplids).pluck(:variation_id)
				  ).pluck(:id)
		
		scope = Aqua.base_scope(experiment.id, smplids)
		#if group_model.name != "Sample" then
			scope = scope.joins(group_model.name.underscore.to_sym)
		#end
		scope = scope.joins("INNER JOIN #{aqua_model.table_name} aqua ON (aqua.variation_id = variation_calls.variation_id AND aqua.organism_id = #{experiment.organism_id})")
		scope = scope.where("variation_calls.id" => ids)
		subject2varcall = scope
		scope = scope.group("aqua.#{params[:annotation_attr]}, #{group_model.table_name}.id")
		select_vals  = case what
		when "presence"
			"DISTINCT variation_calls.variation_id"
		when params[:matrix_value] == "variations"
			"DISTINCT variation_calls.variation_id"
	   when params[:matrix_value] == "baf"
			"(variation_calls.alt_reads/(variation_calls.ref_reads + variation_calls.alt_reads))"
	   when params[:matrix_value] == "genotype"
			"variation_calls.gt"
	   when params[:matrix_value] == "copy-number"
			"variation_calls.cn"
	   end
		
		select_vals = case aggregation
			when "count"
				"COUNT(#{select_vals})"
			when "max"
				"MAX(#{select_vals})"
			when "min"
				"MIN(DISTINCT #{select_vals})"
			when "mean"
				"AVG(DISTINCT #{select_vals})"
			when "sum"
				"SUM(DISTINCT #{select_vals})"
			else
				"GROUP_CONCAT( #{select_vals} SEPARATOR ',')"
		end
		
		#scope = scope.select(["aqua.#{params[:annotation_attr]} AS `#{params[:annotation_attr]}`", "CONCAT(#{group_model.table_name}.name, '(#', #{group_model.table_name}.id, ')') AS subject", "COUNT(DISTINCT variation_calls.variation_id) AS VAL"])
		scope = scope.select(["aqua.#{params[:annotation_attr]} AS `#{params[:annotation_attr]}`", "CONCAT(#{group_model.table_name}.name, '(#', #{group_model.table_name}.id, ')') AS subject", "#{select_vals} AS VAL"])
		matrix = Aqua.scope_to_array(scope)
		matrix = long_to_wide(matrix, "subject", "#{params[:annotation_attr]}", "VAL")
		if (!verbose)
			return(matrix)
		else
			return(
				{
					matrix: matrix,
					subject2varcall: Aqua.scope_to_array(subject2varcall.select([ "CONCAT(#{group_model.table_name}.name, '(#', #{group_model.table_name}.id, ')') AS subject", "variation_calls.id", "aqua.#{params[:annotation_attr]} AS `#{params[:annotation_attr]}`"]))
				}
			)
		end
	end
	
	def panel_to_subject_matrix
		ids = params[:ids]
		if ids.is_a?(Array) then
			ids = ids.map {|id| id.split(" | ")}.flatten
		end
		user = current_user
		panels = user.visible(GenericGeneList)
		grouping_models = [EntityGroup, Entity, SpecimenProbe, Sample].reverse
		aqua_models = get_aqua_models
		require_params  = {
			ids:                 params[:ids],
			panel: panels.map {|p| {id: p.id, name: p.name}},
			column_attribute:    grouping_models,
			annotation: aqua_models.map {|am| am.name},
			selected_samples:    ["Selected samples", "All samples in Project"],
			samples:             params[:samples],
			experiment:          params[:experiment],
			queries:             params[:queries],
			aggregations:        params[:aggregations]
		}
		if determine_missing_params(require_params).size > 0 then
			render_table_details_params(require_params)
		else
			aqua_model  = aqua_models.select {|a| a.name == params[:annotation]}.first
			group_model = grouping_models.select {|a| a.name == params[:column_attribute]}.first
			if !params[:panel].nil? then
				panels = GenericGeneList.where(id: params[:panel])
			end
			#if params[:panel] != " " then
			#	panel = GenericGeneList.find_by_name(params[:panel])
			#else
			#	panel = GenericGeneList.new(name: " ")
			#end
			if aqua_model.nil? or group_model.nil? then
				render text: "Invalid", status: 500
				return true
			end
			require_params  = {
				ids:                 params[:ids],
				panel: 				 panels,
				column_attribute:    group_model,
				annotation: 		 aqua_model,
				annotation_attr:     aqua_model.attribute_names.sort,
				selected_samples:    params[:selected_samples],
				samples:             params[:samples],
				experiment:          params[:experiment],
				queries:             params[:queries],
				aggregations:        params[:aggregations]
			}
			if determine_missing_params(require_params).size > 0 then
				render_table_details_params(require_params)
			else
				if !aqua_model.attribute_names.include?(params[:annotation_attr]) then
					render text: "Invalid", status: 500
					return true
				end
				matrix = get_matrix(params, "count", "presence", true)
				attr_matrix = matrix[:matrix]
				# we need a helper that maps the subject to the selected variation call ids
				subject2varcall_id = {}
				matrix[:subject2varcall].each do |rec|
					subject = rec["subject"]
					gene = rec[params[:annotation_attr]]
					subject2varcall_id[subject] = {} if subject2varcall_id[subject].nil?
					subject2varcall_id[subject][gene] = [] if subject2varcall_id[subject][gene].nil?
					subject2varcall_id[subject][gene] << rec["variation_calls.id"]
				end
				d subject2varcall_id
				# transform attr matrix to subject vs panel list
				# the cells then show the rowname and the concatenated cell values
				panel_genes = Hash[panels.map{|p| [p.name, p.genes]}]
				# initilize the result matrix
				subject_to_panel_matrix = {}
				attr_matrix.first.keys.each do |subject|
					next if subject == params[:annotation_attr]
					next if subject == :id
					#subject_to_panel_matrix[subject] = {id: subject2varcall_id[subject].join(" | "), subject: subject}
					subject_to_panel_matrix[subject] = {id: [], subject: subject}
					subject_to_panel_matrix[subject] = subject_to_panel_matrix[subject].merge(Hash[panel_genes.keys.sort.map{|k| ["##{k}", ""]}]) # have a block of columns at the front that contain the number of hits.
					subject_to_panel_matrix[subject] = subject_to_panel_matrix[subject].merge(Hash[panel_genes.keys.sort.map{|k| [k, []]}])
				end
				# iterate over each gene
				attr_matrix.each do |rec|
					gene = rec[params[:annotation_attr]]
					panels_with_gene = panel_genes.keys.select{|pname| panel_genes[pname].include?(gene)}
					subjects_with_values = rec.keys.select{|k|
						next if k == :id
						next if k == params[:annotation_attr]
						val = rec[k]
						val = val.join("") if val.is_a?(Array)
						val.to_s.strip != ""
					}
					subjects_with_values = subjects_with_values - [params[:annotation_attr], :id]
					varcalls_in_panels = subjects_with_values.map{|subject|
						(subject2varcall_id[subject][gene] || [])
					}.flatten.uniq
					subjects_with_values.each do |subject|
						panels_with_gene.each do |panel_hit|
							subject_to_panel_matrix[subject][panel_hit] << gene
							subject_to_panel_matrix[subject][:id] += varcalls_in_panels #(subject2varcall_id[subject][gene] || [])
						end
					end
				end
				
				# now make sure that each cell is formated properly
				subject_to_panel_matrix.keys.each do |subject|
					subject_to_panel_matrix[subject].keys.each do |colname|
						if (colname == :id) then
							subject_to_panel_matrix[subject][colname] = subject_to_panel_matrix[subject][colname].sort.uniq.join(" | ")
						end
						if subject_to_panel_matrix[subject][colname].is_a?(Array) then
							subject_to_panel_matrix[subject]["##{colname}"] = subject_to_panel_matrix[subject][colname].uniq.size
							subject_to_panel_matrix[subject][colname] = subject_to_panel_matrix[subject][colname].uniq.join(" | ")
						end
					end
				end
				subject_to_panel_matrix = subject_to_panel_matrix.values.flatten
				record_colors = Hash[panel_genes.keys.map{|k| [k, :factor_norm]}]
				max_col_val = panel_genes.keys.map{|k| subject_to_panel_matrix.map{|rec| rec["##{k}"]}}.flatten.max
				colors = Hash[panel_genes.keys.map{|k|
					["##{k}", Aqua.create_color_gradient([0, max_col_val], ["white", "lightsalmon"])]
				}]
				aqua_actions = {}
				Aqua.route_paths.each do |description, url|
					aqua_actions[description] = {url: url, params: {experiment_id: params[:experiment], samples: params[:samples], queries: params["queries"], aggregations: params["aggregations"]}}
				end
				aqua_actions = aqua_actions.merge(
						{
								"Look-up variations in other samples" => {url: details_experiments_path(experiment: params[:experiment]),    params: {samples: params[:samples], tags: 'yes', queries: params["queries"], aggregations: params["aggregations"]}},
								"Show interactions" => {url: interactions_experiments_path(experiment: params[:experiment]),                 params: {samples: params[:samples], queries: params["queries"], aggregations: params["aggregations"]}},
								"Attribute matrix" => {url: attribute_matrix_experiments_path(experiment: params[:experiment]),              params: {samples: params[:samples], queries: params["queries"], aggregations: params["aggregations"]}},
								"Gene panel to subject" => {url: panel_to_subject_matrix_experiments_path(experiment: params[:experiment]),  params: {samples: params[:samples], queries: params["queries"], aggregations: params["aggregations"]}},
								"Save selected records" => {url: save_resultset_experiments_path(experiment: params[:experiment]),                params: {samples: params[:samples], queries: params["queries"], aggregations: params["aggregations"]}}
						}
				)
				render_table(subject_to_panel_matrix,
							 title:  "#{subject2varcall_id.keys.size} subjects vs #{panel_genes.keys.size} panels".html_safe,
							 id:     "gp_matrix_#{Time.now.to_i}",
							 record_colors: record_colors,
							 colors: colors,
							 actions: aqua_actions
				)
			end
		end
		
	end
	
	def attribute_matrix
		Aqua._reload if Rails.env == "development"
		ids = params[:ids]
		if ids.is_a?(Array) then
			ids = ids.map {|id| id.split(" | ")}.flatten
		end
		
		aqua_models = get_aqua_models

		grouping_models = [EntityGroup, Entity, SpecimenProbe, Sample].reverse
		require_params  = {
				ids:                 params[:ids],
				annotation: aqua_models.map {|am| am.name},
				column_attribute:    grouping_models,
				selected_samples:    ["Selected samples", "All samples in Project"],
				samples:             params[:samples],
				experiment:          params[:experiment],
				queries:             params[:queries],
				aggregations:        params[:aggregations]
		}
		if determine_missing_params(require_params).size > 0 then
			render_table_details_params(require_params)
		else
			aqua_model  = aqua_models.select {|a| a.name == params[:annotation]}.first
			group_model = grouping_models.select {|a| a.name == params[:column_attribute]}.first
			if aqua_model.nil? or group_model.nil? then
				render text: "Invalid", status: 500
				return true
			end
			require_params = {
					ids:                 params[:ids],
					annotation: aqua_model.name,
					column_attribute:    params[:column_attribute],
					annotation_attr:       aqua_model.attribute_names.sort,
					aggregation_method:  ["count", "concat", "mean", "max", "min", "sum"],
					matrix_value:        ["presence", "variations", "baf", "genotype", "copy-number"],
					remove_emtpy_columns: ["no", "yes"],
					selected_samples:    params[:selected_samples],
					samples:             params[:samples],
					experiment:          params[:experiment],
					queries:             params[:queries],
					aggregations:        params[:aggregations]
			}
			if determine_missing_params(require_params).size > 0 then
				render_table_details_params(require_params)
			else
				if !aqua_model.attribute_names.include?(params[:annotation_attr]) then
					render text: "Invalid", status: 500
					return true
				end
				
				experiment  = Experiment.find(params[:experiment])
				organism_id = experiment.organism.id
				
				if 1 == 0 then
					attr_matrix = get_matrix(params, params[:aggregation_method], params[:matrix_value])
				else
					
					
					# if the user wants to see the data from all samples in the project we need to
					# edit some stuff, because he selected variation_calls ids. We need to find the
					# variations for these varcall_ids and then find the variation call ids form all
					# samples in the project
					if params[:selected_samples] == 'All samples in Project' then
						smplids = experiment.sample_ids
					else
						smplids = params[:samples]
					end
					# make sure that the variation call ids contain the samples we want to see.
					ids = VariationCall
							  .where(variation_id:
										 VariationCall.where(id: ids).where(sample_id: smplids).pluck(:variation_id)
							  ).pluck(:id)
	
					if group_model.name != "Sample" then
						objs = group_model.joins(:samples).where("samples.id" => smplids).order("#{group_model.table_name}.name").uniq
					else
						objs = group_model.where("samples.id" => smplids).order("#{group_model.table_name}.name").uniq
					end
					
					obj2_variation_attribute = {}
					obj2_variation_2varcall  = {}
					var2obj                  = {}
					objs.each do |o| # for each object (EntityGroup, Entity, Specimen, Sample)
						obj_attributes = {}
						obj_varcall    = {}
						varcalls   = o.variation_calls.where("variation_calls.id" => ids) # get variation calls
						if params[:matrix_value] == "presence" then
							varcalls.select(["variation_calls.id", "variation_calls.variation_id"]).uniq.each {|vc|
								obj_attributes[vc.variation_id] ||= [] if obj_attributes[vc.variation_id].nil?
								obj_attributes[vc.variation_id] << 1
								obj_varcall[vc.variation_id] ||= []
								obj_varcall[vc.variation_id] << vc.id
							}
						elsif params[:matrix_value] == "variations" then
							varcalls.select(["variation_calls.id", "variation_calls.variation_id"]).uniq.each {|vc|
								obj_attributes[vc.variation_id] ||= [] if obj_attributes[vc.variation_id].nil?
								obj_attributes[vc.variation_id] << vc.variation_id
								obj_varcall[vc.variation_id] ||= []
								obj_varcall[vc.variation_id] << vc.id
							}
						elsif params[:matrix_value] == "baf" then
							varcalls.select(["variation_calls.id", "variation_calls.variation_id", :ref_reads, :alt_reads]).uniq.each {|vc|
								obj_attributes[vc.variation_id] ||= [] if obj_attributes[vc.variation_id].nil?
								baf                         = vc.alt_reads.to_f/(vc.ref_reads.to_f+vc.alt_reads.to_f)
								baf                         = baf.nan? ? 0 : baf
								obj_attributes[vc.variation_id] << baf
								obj_varcall[vc.variation_id] ||= []
								obj_varcall[vc.variation_id] << vc.id
							}
						elsif params[:matrix_value] == "genotype"
							varcalls.select(["variation_calls.id", "variation_calls.variation_id", "variation_calls.gt"]).uniq.each {|vc|
								obj_attributes[vc.variation_id] ||= [] if obj_attributes[vc.variation_id].nil?
								obj_attributes[vc.variation_id] << vc.gt
								obj_varcall[vc.variation_id] ||= []
								obj_varcall[vc.variation_id] << vc.id
							}
						elsif params[:matrix_value] == "copy-number"
							varcalls.select(["variation_calls.id", "variation_calls.variation_id", "variation_calls.cn"]).uniq.each {|vc|
								obj_attributes[vc.variation_id] ||= [] if obj_attributes[vc.variation_id].nil?
								obj_attributes[vc.variation_id] << vc.cn
								obj_varcall[vc.variation_id] ||= []
								obj_varcall[vc.variation_id] << vc.id
							}
						end
						obj_attributes.keys.each do |varid|
							var2obj[varid] = [] if var2obj[varid].nil?
							var2obj[varid] << o
						end
						obj2_variation_attribute[o] = obj_attributes
						obj2_variation_2varcall[o] = obj_varcall
					end
					attrs       = aqua_model.where(variation_id: var2obj.keys)
														.where(organism_id: organism_id)
														.select(["variation_id as variation_id", "#{params[:annotation_attr]} AS #{params[:annotation_attr]}_attr"]) # using this alias makes sure that we get two distinct records in the array
														.uniq
														.map {|x|
						x.attributes.values.flatten
					}
					# attr matrix is {attr: {attribute_name: attr_value, obj1: cnt_obj1, obj2: cnt_obj2 .... }}
					attr_matrix = {}
					rowname = "#{params[:annotation]}.#{params[:annotation_attr]}"
					attrs.each do |variation_id, attribute|
						attr_matrix[attribute] = {rowname => attribute, id: []}.merge(Hash[objs.map {|o| [o.name, []]}]) if attr_matrix[attribute].nil?
						var2obj[variation_id].each do |o|
							attr_matrix[attribute][o.name] << obj2_variation_attribute[o][variation_id]
							attr_matrix[attribute][:id] << obj2_variation_2varcall[o][variation_id] #o.variation_calls.where(variation_id: variation_id).pluck(:id) # obj2_variation_attribute[o][:id]
						end
					end
					attr_matrix    = attr_matrix.values.flatten(1)
					
					row_agg_name = "row.#{params[:aggregation_method]}"
					col_agg_name = "col.#{params[:aggregation_method]}"
					row_sums = {}
					col_sums = Hash.new(0)
					attr_matrix.each_with_index do |rec, i|
						rec[:id] = rec[:id].sort.flatten.join(" | ")
						objs.each do |o|
							rec[o.name] = [rec[o.name]] unless rec[o.name].is_a?(Array)
							rec[o.name] = case params[:aggregation_method]
															when "count"
																rec[o.name].flatten.uniq.size
															when "max"
																rec[o.name].flatten.max
															when "min"
																rec[o.name].flatten.min
															when "mean"
																rec[o.name].flatten.to_scale.mean.round(4)
															when "sum"
																rec[o.name].flatten.to_scale.sum
															else
																rec[o.name].flatten.sort.join(",")
														end
							if (rec[o.name].to_f.nan?)
								rec[o.name] = nil
							end
							case params[:aggregation_method]
								when "count"
									col_sums[o.name] += rec[o.name]
								when "max"
									col_sums[o.name] = [col_sums[o.name].to_f, rec[o.name].to_f].max
								when "min"
									col_sums[o.name] = [col_sums[o.name].to_f, rec[o.name].to_f].min
								when "mean"
									col_sums[o.name] = [col_sums[o.name].to_f, rec[o.name]].to_scale.mean.round(4)
								when "sum"
									col_sums[o.name] += rec[o.name]
								else
									col_sums[o.name] = ""
							end
							row_sums[rec[:id]] ||= []
							row_sums[rec[:id]] << rec[o.name]
						end
						rec[row_agg_name] = case params[:aggregation_method]
																	when "count"
																		row_sums[rec[:id]].reject(&:nil?).inject(&:+)
																	when "max"
																		row_sums[rec[:id]].reject(&:nil?).max
																	when "min"
																		row_sums[rec[:id]].reject(&:nil?).min
																	when "mean"
																		row_sums[rec[:id]].reject(&:nil?).to_scale.mean.round(4)
																	when "sum"
																		row_sums[rec[:id]].reject(&:nil?).inject(&:+)
																	else
																		""
																end
					end
	
					obj_column_colors = Hash[objs.map {|o| [o.name, :factor]}]
					if params[:aggregation_method] != "concat" then
						# min_max = attr_matrix.map(&:values).flatten.reject(&:nil?).map(&:to_f).reject(&:nan?)
						min_max = attr_matrix.map{|rec| (objs.map(&:name) + [row_agg_name]).map{|o| rec[o] }}.flatten.reject(&:nil?).map(&:to_f).reject(&:nan?)
						if min_max.size == 0 then
							min_max = [0, 0.5, 1]
						else
							min_max = [
									min_max.min,
									min_max.to_scale.mean,
									min_max.max
							]
						end
						(objs.map(&:name) + [row_agg_name]).each do |o|
							obj_column_colors[o] = Aqua.create_color_gradient(min_max, ["palegreen", "lightyellow", "salmon"][0...min_max.size])
						end
					end
					if params['remove_emtpy_columns'] == 'yes' then
						col_has_entry = {
							"#{rowname}" => true,
							:id => true,
							"row.count" => true,
							"row.mean" => true
						}
						attr_matrix.each do |row|
							row.each do |colname, cellval|
								col_has_entry[colname] = false if col_has_entry[colname].nil?
								is_empty = case params[:aggregation_method]
								           when "count"
									           cellval.to_f == 0.0
								           when "max"
									           cellval.to_s.strip == ""
								           when "min"
									           cellval.to_s.strip == ""
								           when "mean"
									           cellval.to_s.strip == ""
								           when "sum"
									           cellval.to_s.strip == ""
								           else
									           cellval.to_s.strip == ""
								           end
								col_has_entry[colname] = true if !is_empty
							end
						end
						attr_matrix.each do |row|
							col_has_entry.each do |colname, has_entry|
								next if has_entry
								row.delete(colname)
							end
						end
					end
					pp ".......................................".magenta
					pp col_has_entry
					pp ".......................................".magenta
					attr_matrix << {id: "", "#{params[:annotation]}.#{params[:annotation_attr]}" => col_agg_name}.merge(col_sums)
				end
				aqua_actions = {}
				Aqua.route_paths.each do |description, url|
					aqua_actions[description] = {url: url, params: {experiment_id: experiment.id, samples: smplids, queries: params["queries"], aggregations: params["aggregations"]}}
				end
				aqua_actions = aqua_actions.merge(
						{
								"Look-up variations in other samples" => {url: details_experiments_path(experiment: experiment.id),    params: {samples: smplids, tags: 'yes', queries: params["queries"], aggregations: params["aggregations"]}},
								"Show interactions" => {url: interactions_experiments_path(experiment: experiment.id),                 params: {samples: smplids, queries: params["queries"], aggregations: params["aggregations"]}},
								"Attribute matrix" => {url: attribute_matrix_experiments_path(experiment: experiment.id),              params: {samples: smplids, queries: params["queries"], aggregations: params["aggregations"]}},
								"Gene panel to subject" => {url: panel_to_subject_matrix_experiments_path(experiment: experiment.id),  params: {samples: smplids, queries: params["queries"], aggregations: params["aggregations"]}},
								"Save selected records" => {url: save_resultset_experiments_path(experiment: experiment.id),          params: {samples: params[:samples], queries: params["queries"], aggregations: params["aggregations"]}}
						}
				)
				render_table(attr_matrix,
										 title:  "#{params[:annotation_attr]} vs #{params[:column_attribute]} showing #{params[:aggregation_method]} of #{params[:matrix_value]} for all variants",
										 id:     "attribute_matrix_#{Time.now.to_i}",
										 colors: obj_column_colors,
										 actions: aqua_actions
				)
			end
		end
	end
end
