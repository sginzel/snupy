module AquaHelper
	def base_scope(experimentid = nil, sample_ids = nil, varcall_cols = false, sample_cols = false, experiment_cols = false, variation_cols = false)
		
		if !experimentid.nil? then
			exps = Experiment.find(experimentid)
			exps = [exps] unless exps.is_a?(Array)
			if sample_ids.nil?
				sample_ids = exps.map{|exp| exp.associated_samples.pluck("samples.id")}.flatten.uniq
			else
				exps_smpl_ids = exps.map{|exp| exp.associated_samples.map(&:id)}.flatten.uniq
				sample_ids.select!{|sid| exps_smpl_ids.include?(sid.to_i)}
			end
		elsif sample_ids.nil? then
			raise("base_scope needs a experiment or a list of samples")
		end
		
		# .joins(:variation_calls)
						# .joins({:variations => [:region, :alteration]})
		#scope = Experiment
		#				.joins({
		#						:variation_calls => {
		#							:variation => [:region, :alteration]
		#						}
		#					})
		#				.where("experiments.id" => experimentid)
		#				.where("samples.id" => sample_ids)
		#				.select("variation_calls.id AS `variation_calls.id`")

		raise "No sample ids given for BaseScope" if sample_ids.size == 0

		# TODO: check region filter and make sure it includes joins to regions
		scope = VariationCall
						.where("sample_id" => sample_ids)
						.select("variation_calls.id AS `variation_calls.id`")
		if sample_cols
			scope = scope.joins(:sample)
		end
		if experiment_cols
			scope = scope.joins(:experiments)
		end
		
		if variation_cols
			scope = scope.joins({:variation => [:region, :alteration]})
		end
		cols2add = []
		cols2add << VariationCall if varcall_cols
		cols2add << Sample        if sample_cols
		cols2add << Experiment    if experiment_cols
		cols2add += [Region, Alteration] if variation_cols
		cols2add.each do |mdl|
			mdl.attribute_names.reject{|cname| cname =~ /((created|updated)_at$)/}.each do |colname|
				scope = scope.select("#{mdl.table_name}.#{colname} AS `#{mdl.table_name}.#{colname}`")
			end 
		end
		scope
	end
	
	def extract_where_values(scope, table, columns = nil)
		where_classes = [
			Arel::Nodes::Equality, # creates when using .where(colname: "value")
			Arel::Nodes::In        # created when using .where(colname: [1,2,3])
			# String                 # created when using .where("colname = value")
		]
		columns = ActiveRecord::Base.connection.execute("DESCRIBE #{table}").to_a.map(&:first) if columns.nil?
		columns = [columns] unless columns.is_a?(Array)
		columns = columns.map(&:to_s)
		where_nodes = scope.where_values.select{|wv|
			where_classes.include?(wv.class)
		}.find_all{|node|
			node.left.relation.name.to_s == table.to_s &&
			columns.include?(node.left.name.to_s)
		}
		ret = Hash[
			where_nodes.map{|w|
				[
					"#{w.left.relation.name}.#{w.left.name}", 
					w.right
					]
				}
		]
		return ret
	end
	
	def is_applicable?(required)
		required.all? do |model, cols_or_assocs|
			ret = true
			d "[WARNING] #{model.table_name} does not exist" if Rails.env == "development" and !(model.table_exists?)
			return false unless model.table_exists?
			cols_or_assocs = [cols_or_assocs] unless (cols_or_assocs.is_a?(Array) || cols_or_assocs.is_a?(Hash))
			tblname = model
			tblname = model.table_name if ActiveRecord::Base.descendants.include?(model)
			if (cols_or_assocs.is_a?(Array))
				cols_or_assocs.each do |col_or_assoc|
					assoc = Aqua.find_association(model, col_or_assoc)
					if assoc.nil? then
						ret = model.attribute_names.include?(col_or_assoc.to_s)
						Aqua.log_warn("[WARNING] Neither association nor column name found for #{model} => #{col_or_assoc}") if ret == false
					end
				end
			else
				cols_or_assocs.each do |assoc_model, cols|
					if !(assoc_model.to_s.downcase == "select") then
						assoc = Aqua.find_association(model, assoc_model)
						cols = [cols] unless cols.is_a?(Array)
						if assoc.nil? then
							ret = false
							Aqua.log_warn "[WARNING] Association not found for #{model} => #{assoc_model}"
						else # check if the associated tables has the required columns
							ret = cols.all?{|c| assoc.klass.attribute_names.include?(c.to_s)}
							Aqua.log_warn "[WARNING] Some columns not found for associated model #{model} => #{assoc_model} => [#{cols.join(", ")}]" if ret == false
						end
					else
						ret = cols.all?{|c| model.attribute_names.include?(c.to_s)}
						Aqua.log_warn "[WARNING] Some columns not found for model #{model}/#{assoc_model} => [#{cols.join(", ")}]" if ret == false
					end
				end
			end
			ret
		end
	end
	
	# add JOIN statements to the scope. This is derived from the :requires entry in the configuration
	# The requirements can be defined as follows:
	# requires: SomeModel
	# requires: {
	#             SomeModel => [:attr1, :attr2, ...],
	#             SomeOtherModel => {
	#               SomeAssociation => [:association_attribute1, :association_attribute2, ...],
	#               :some_other_association => [some_other_association_attribute, ...],
	#               select: [:some_other_model_attribute1, :some_other_attribute2,...]
	#             }
	# }
	# Links between associations are derived through the ActiveRecord::Base.reflect_on_all_associations() method on the model. Nested associations are not supported.
	# If you need attributes from an association and the model you can use select as the association name (aliases are columns and cols).
	# See _add_joins() for more details. 
	def add_required(scope, 
												add_select = false, 
												organismid = nil,
												required = (self.configuration[:model] || self.configuration[:requires]),
												models2skip = [])#[Experiment, VariationCall, Variation, Region, Alteration, Sample])
		# Those models are part of the base_scope anyways.
		
		table_alias = {}
		
		# first add all required joins that are joined by variation_id
		varidjoins = required
		varidjoins = required.keys if required.is_a?(Hash)
		varidjoins = [varidjoins] unless varidjoins.is_a?(Array)
		varidjoins.each do |model|
			next if models2skip.include?(model)
			if (ActiveRecord::Base.descendants.include?(model)) then
				jointbl = model.table_name
			else
				jointbl = model
			end
			# check if the model requires the table name to be aliased
			jointbl_name = nil
			jointbl_name = model.aqua_table_alias if model.respond_to?(:aqua_table_alias)
			table_alias[jointbl_name] = jointbl
			
			# check if the model is an inherited model - this requires additional conditions in the join clause
			condition = nil
			if (ActiveRecord::Base.descendants.include?(model)) then
				if model.attribute_names.include?(model.inheritance_column)
					if jointbl_name.nil? then
						condition = ["#{model.inheritance_column} = '#{model.name.demodulize}'"]
					else
						condition = ["#{jointbl_name}.#{model.inheritance_column} = '#{model.name.demodulize}'"]
					end
				end
			end
			
			# do not allow cartisean joins...
			scope_tables = get_tables(scope)
			next if scope_tables.include?(jointbl)
			
			if (jointbl == "variations") then
				scope = _add_join(scope, "variation_calls", jointbl, "variation_id", "id", jointbl_name, condition)
			elsif model.attribute_names.include?("organism_id") and model.attribute_names.include?("variation_id") then
				scope = _add_join(scope, "variation_calls", jointbl, "variation_id", "variation_id", organismid, jointbl_name, condition)
			elsif !model.attribute_names.include?("organism_id") and model.attribute_names.include?("variation_id") then
				scope = _add_join(scope, "variation_calls", jointbl, "variation_id", "variation_id", nil, jointbl_name, condition)
			elsif !model.attribute_names.include?("organism_id") and !model.attribute_names.include?("variation_id") then
				scope = _add_join(scope, "variation_calls", jointbl, "#{jointbl.singularize}_id", "id", nil, jointbl_name, condition)
			else
				raise "I dont know how to join #{jointbl} to variation_calls"
			end
			
			#if (jointbl != "variations") then
			#	if (model.attribute_names.include?("organism_id"))
			#		scope = _add_join(scope, "variation_calls", jointbl, "variation_id", "variation_id", organismid)
			#	else
			#		scope = _add_join(scope, "variation_calls", jointbl, "variation_id", "variation_id", nil)
			#	end
			#else
			#	scope = _add_join(scope, "variation_calls", jointbl, "variation_id", "id")
			#end
		end # end if add join tables
		
		select_cols = []
		if ActiveRecord::Base.descendants.include?(required) then
			required = [required]
		end
		required.each do |model, cols_or_assoc|
			tblname = model
			if ActiveRecord::Base.descendants.include?(model)
				tblname = model.table_name
				tblname = model.aqua_table_alias if model.respond_to?(:aqua_table_alias)
			end 
			
			if cols_or_assoc.nil? then
				if ActiveRecord::Base.descendants.include?(model)
					cols_or_assoc = model.attribute_names
				else
					cols_or_assoc = []
				end
			end
			
			if models2skip.include?(model) then
				cols_or_assoc.each do |colname|
					select_cols << "#{tblname}.#{colname} AS `#{tblname}.#{colname}`"
				end
			end
			next if models2skip.include?(model)
			if cols_or_assoc.is_a?(Hash) then
				cols_or_assoc.each do |assoc_model, assoc_cols|
					if !%w(columns cols select).include?(assoc_model.to_s) then
						assoc = find_association(model, assoc_model)
						raise "Association #{assoc_model} not found for #{model}" if assoc.nil?
						scope = _add_assoc(scope, tblname, assoc)
						assoc_cols.each do |colname|
							select_cols << "#{assoc.table_name}.#{colname} AS `#{assoc.table_name}.#{colname}`"
						end
					else
						assoc_cols.each do |colname|
							select_cols << "#{tblname}.#{colname} AS `#{tblname}.#{colname}`"
						end
					end
				end
			else # else treat it as an array
				cols_or_assoc = [cols_or_assoc] unless cols_or_assoc.is_a?(Array)
				cols_or_assoc.each do |col_or_assoc|
					# check if there is a association associated with this name
					if !models2skip.include?(model)
						assoc = find_association(model, col_or_assoc)
					else
						assoc = nil
					end
					if !assoc.nil? then
						scope = _add_assoc(scope, tblname, assoc)
						# add all columns from the asscoiation
						assoc.klass.attribute_names.each do |colname|
							next if colname == "created_at" or colname == "updated_at" or colname == "id"
							select_cols << "#{assoc.klass.table_name}.#{colname} AS `#{assoc.klass.table_name}.#{colname}`"
						end
					else # if it is not then we can consider the content to be column names
						select_cols << "#{tblname}.#{col_or_assoc} AS `#{tblname}.#{col_or_assoc}`"
					end
				end
			end
		end # end of required.each
		if (add_select)
			scope = scope.select(select_cols)
		end
		scope
	end
	
		# TODO The current version only returns the column names as the hash keys
	# But we need the keys to be "tablename"."colname" in order to work right.
	# we should add aliases...
	def scope_to_array(scope, alias_columns = false, include_timestamps = false, dbconnection = ActiveRecord::Base, &block)
		if (alias_columns)
			if scope.select_values.size == 0
				# lets start with the klass
				cols = []
				scope.klass.attribute_names.each do |colname|
					next if colname == "created_at" and !include_timestamps
					next if colname == "updated_at" and !include_timestamps
					cols << "#{scope.klass.table_name}.#{colname} AS `#{scope.klass.table_name}.#{colname}`"
				end
				if scope.joins_values.size > 0 then
					scope.joins_values.each do |potential_assoc|
						assocs = find_association(scope.klass, potential_assoc)
						next if assocs.nil?
						assocs = [assocs] unless assocs.is_a?(Array)
						assocs.flatten.each do |assoc|
							assoc.klass.attribute_names.each do |colname|
								next if colname == "created_at" and !include_timestamps
								next if colname == "updated_at" and !include_timestamps
								cols << "#{assoc.klass.table_name}.#{colname} AS `#{assoc.klass.table_name}.#{colname}`"
							end
						end
					end
				end
			else
				cols = scope.select_values
				cols = cols.map{|colname|
					if !colname =~ /.* AS `.*`/ then
						"#{colname} AS `#{colname}`"
					else
						colname
					end
				}
			end
			# scope.select_values = cols
		end
		if alias_columns
			sqlstatement = scope.select(cols).to_sql
		else
			sqlstatement = scope.to_sql
		end
		File.open("tmp/last_sql_to_arry.sql", "w+"){|fout|
			if (sqlstatement.length > (1024*1024)) 
				fout.write(sqlstatement[0...1024] + "..." + sqlstatement[-1024...-1])
				fout.write("\nSTATEMENT TRUNCATED BECAUSE ITS TOO LARGE (#{sqlstatement.size} characters)")
			else
				fout.write(sqlstatement + "\n\n")
			end
			fout.flush
		}
		# do not log those statements in the log file
		dbconnection.logger.info("Querying database with a AQuA statement, which is not shown in this log.")
		dbconnection.logger.silence do # prevent writing large queries to log
			if dbconnection.connection.adapter_name == 'Mysql2' and block_given? then
				begin
					result = dbconnection.connection.instance_eval{@connection}.query(sqlstatement, stream: true, as: :hash) # when we stream the call will be asynchronous
					result.each do |r|
						yield r
					end
				#rescue Exception => e
				#		raise e
				ensure
					# dbconnection.connection.instance_eval{@connection}.free
					if result.respond_to? :free then
						result.free
					end
				end
			else
				ret = dbconnection.connection.exec_query(sqlstatement).to_hash
				if block_given? then
					ret.each do |r|
						yield r
					end
				else
					return ret
				end
			end
		end
	end
	
	def find_association(model, assoc_model_or_name)
		ret = []
		# d "Finding asssoc #{model} => #{assoc_model_or_name}"
		# d "------------------------------------"
		if assoc_model_or_name.is_a?(Hash) then
			assoc_model_or_name.each do |modelname, assocs|
				if modelname.to_s.downcase == "select" then
					ret << model
				else
					ret << find_association(model, modelname)
					actualmodel = Kernel.const_get(modelname.to_s.singularize.downcase.capitalize)
					next unless ActiveRecord::Base.descendants.include?(actualmodel)
					ret << find_association(actualmodel, assocs)
				end
			end
		elsif assoc_model_or_name.is_a?(Array)
			assoc_model_or_name.each do |assoc|
				ret << find_association(model, assoc)
			end
		else
			ret << model.reflect_on_all_associations().select{ |a|
				has_it = false
				# d "#{a.pretty_inspect} <-> #{assoc_model_or_name}"
				# d "*****************************************++"
				if ActiveRecord::Base.descendants.include?(assoc_model_or_name)
					# this does not include the associations that are inherent when assoc_model has inherited properties
					has_it = (a.name == assoc_model_or_name || a.class_name == assoc_model_or_name.name)
					has_it = has_it || (assoc_model_or_name.ancestors.any?{|ancestor|
						(ancestor.name == a.class_name)
					})
				else
					has_it = (a.name == assoc_model_or_name || a.class_name == assoc_model_or_name || a.klass == assoc_model_or_name)
				end
				has_it
			}.first
		end
		return ret.first if ret.size <= 1
		ret.reject(&:nil?)
	end
	
	def traverse_hash(hsh, &block)
		if hsh.is_a?(Hash)
			ret = []
			hsh.each do |k,v|
				ret << [k, traverse_hash(v, &block)]
			end
			return ret
		else
			if block_given?
				yield hsh
			else
				return hsh
			end
		end
	end
	
	def all_associations()
		ret = {}
		assoc2models = ActiveRecord::Base.descendants.map{|ar|
			association_to_model(ar)[ar]
		}
		assoc2models.each do |hsh|
			ret.merge!(hsh)
		end
		return ret
	end
	
	def association_to_model(scope)
		#d "-----"
		#d scope
		ret = scope.reflect_on_all_associations().map{|a|
			#d "+++++"
			#d a
			#d "a.nil?: #{a.nil?}"
			#d "a.respond: #{a.respond_to?(:klass)}"
			#d "a.klass: #{a.klass}"
			#d "***"
			if (!a.nil?)
				[
					a.name, 
					a.klass
				]
			else 
				nil
			end
		}.reject(&:nil?)
		if scope.is_a?(ActiveRecord::Relation)
			{scope.klass => Hash[ret]}
		else
			{scope => Hash[ret]}
		end
	end
	
	def get_associations(scope)
		relations = [scope.from_value]
		scope.joins_values.each do |jv|
			relations << traverse_hash(jv)
		end
		relations = relations.flatten.uniq.reject(&:nil?)
		available_relations = all_associations()
		assocs = [scope.klass] + relations.map{|r|
			( available_relations[r] || r.to_sym )
		}
		assocs.uniq
	end
	
	def get_tables(scope)
		get_associations(scope).map{|a|
			if a.is_a?(Symbol)
				a
			else
				a.table_name
			end
		}
	end
	
	# this way MySQL is able to use the index properly. Results in about 3% more performance for 
	def quick_in(col, ids, table, table_id = "id", quote = false)
		if !quote then
			"#{col} IN (SELECT #{table_id} FROM #{table} WHERE #{table_id} IN (#{ids.join(",")}))"
		else
			"#{col} IN (SELECT #{table_id} FROM #{table} WHERE #{table_id} IN (#{ids.map{|x| "'#{x}'"}.join(",")}) ORDER BY #{table_id})"
		end
	end
	
	def quick_not_in(col, ids, table, table_id = "id", quote = false)
		if !quote then
			"#{col} NOT IN (SELECT #{table_id} FROM #{table} WHERE #{table_id} IN (#{ids.join(",")}))"
		else
			"#{col} NOT IN (SELECT #{table_id} FROM #{table} WHERE #{table_id} IN (#{ids.map{|x| "'#{x}'"}.join(",")}) ORDER BY #{table_id})"
		end
	end
	
	def _add_assoc(scope, modeltbl, assoc, organismid = nil, allow_cartesian = false)
		# do not allow cartisean joins...
		return scope if get_tables(scope).include?(modeltbl) and (not allow_cartesian)
		if (!assoc.options[:join_table].nil?) then
			assoctbl = assoc.options[:join_table]
			#jointbl = assoc.plural_name
			jointbl = assoc.klass.table_name
			forkey = (assoc.foreign_key || assoc.options[:foreign_key])
			assocforkey = (assoc.association_foreign_key || assoc.options[:association_foreign_key])
			# add join to n:m table
			scope = _add_join(scope, modeltbl, assoctbl, "id", forkey)
			# add join from n:m to target
			scope = _add_join(scope, assoctbl, jointbl, assocforkey, "id")
		else
			#jointbl = assoc.plural_name
			jointbl = assoc.klass.table_name
			primkey = (assoc.options[:primary_key] || "#{assoc.name}_id")
			forkey = (assoc.options[:foreign_key] || "id")
			scope = _add_join(scope, modeltbl, jointbl, primkey, forkey, organismid)
		end
		scope
	end
	
	def _add_join(scope, tbl, jointbl, primkey = "id", forkey = "id", organismid = nil, tblalias = nil, conditions = nil)
		join_statement = _get_join_statement(tbl, jointbl, primkey, forkey, organismid, tblalias, conditions)
		scope.joins(join_statement)
	end
	
	def _get_join_statement(tbl, jointbl, primkey = "id", forkey = "id", organismid = nil, tblalias = nil, conditions = nil)
		jointblstatement = jointbl
		# jointblstatement = "#{jointbl} AS #{tblalias}" unless tblalias.nil?
		jointblstatement = "#{jointbl} `#{tblalias}`" unless tblalias.nil?
		aliasedjointbl = jointbl
		aliasedjointbl = tblalias unless tblalias.nil?
		
		condition_statement = ""
		if !conditions.nil? then
			conditions = [conditions] unless conditions.is_a?(Array)
			conditions.each do |cond|
				condition_statement << " AND #{ActiveRecord::Base.__send__(:sanitize_sql, cond, "")}"
			end
		end
		
		if organismid.nil? then
			join_statement = "INNER JOIN #{jointblstatement} ON (#{tbl}.#{primkey} = #{aliasedjointbl}.#{forkey} #{condition_statement})"
		else
			join_statement = "INNER JOIN #{jointblstatement} ON (#{tbl}.#{primkey} = #{aliasedjointbl}.#{forkey} AND #{aliasedjointbl}.organism_id = #{organismid} #{condition_statement})"
		end
		
		join_statement
	end
	
	def match_regexp_key(hsh, k)
		hsh = {} if hsh.nil?
		return (hsh[k] || hsh[k.to_s]) unless (hsh[k] || hsh[k.to_s]).nil?
		if (matching_key = hsh.keys.find(nil){|hk| hk.is_a?(Regexp) and k.to_s =~ hk }) then
			return(hsh[matching_key])
		else
			return nil
		end
	end

	
end