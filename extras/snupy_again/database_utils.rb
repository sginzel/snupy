module SnupyAgain
	module DatabaseUtils

		## create a lookup from an array with given keys
		def self.create_lookup(arr, by, reverse = nil, &block)
			ret = {}
			arr.map{|a|
				if not block_given? then
					key = by.map{|b|a[b]}.join(":")
				else
					key = yield a
				end
				if ret[key].nil? then
					ret[key] = a
				else
					if !ret[key].is_a?(Array) then
						Rails.logger.warn "[WARN] #{key} has more than one element when generating the lookup"
						ret[key] = [ret[key], a]
					else
						ret[key] << a
					end
				end
			}
			# ret = Hash[]
			if not reverse.nil? then
				ret.keys.each do |rk|
					raise "can not create reverse lookup for ambigious relations (#{ret[rk]})" if ret[rk].is_a?(Array)
					raise "reverse lookup (#{reverse}) does not exist for (#{ret[rk]})" if ret[rk][reverse].nil?
					raise "collision detected when creating reverse lookup" if not ret[ret[rk][reverse]].nil? 
					ret[ret[rk][reverse]] = ret[rk]
				end
			end
	
			ret.instance_variable_set(:@by, by)
			ret.instance_variable_set(:@reverse, reverse)
			ret.instance_variable_set(:@has_keygen, block_given?)
			if block_given? then
				ret.instance_variable_set(:@keygen, block)
			else
				ret.instance_variable_set(:@keygen, nil)
			end
			
			def ret.get_by_key(values)
				raise ArgumentError.new "#{values.size} given but #{@by.size} expected" if values.size < @by.size and (not @has_keygen)
				#if @has_keygen then
				#	self[@keygen.call(values)]
				#else
					if values.is_a?(Array) then
						return self[values.join(":")]
					end
					if values.is_a?(Hash) then
						raise ArgumentError.new "not all keys found in given Hash (#{@by.join(",")} expected - #{values.keys.join(",")} given)" if @by.any?{|by| !(values.keys.include?(by) or values.keys.include?(by.to_sym))}
						k = @by.map{|b| (values[b] || values[b.to_sym])}
						return self[k.join(":")]
					end
				#end
				raise ArgumentError.new "Array or Hash expected to retrieve a key from the lookup"
				# return self[values]
			end
			
			def ret.has_key?(values)
				!get_by_key(values).nil?
			end
	
			def ret.add_key(elem)
				if @has_keygen then
					k = @keygen.call(elem)
				else
					k = @by.map{|b|elem[b]}.join(":")
				end
				raise "key #{k} already exists" unless self[k].nil?
				self[k] = elem
				if not @reverse.nil? then
					raise "reverse lookup key #{elem[@reverse]} already exists" unless self[elem[@reverse]].nil?
					self[elem[@reverse]] = self[k]
				end
			end
	
			return ret
		end
	
		def self.lookup_or_create(hsh, model, lookup, &block)
			raise ArgumentError.new "lookup does not respond to has_key? function" unless lookup.respond_to?(:has_key?)
			if !lookup.has_key?(hsh) then
				if !block_given? then
					ret = model.new(hsh)
				else
					ret = yield hsh
				end
				if !ret.persisted? then
					ret.save! 
					lookup.add_key(ret)
				end
			else
				ret = lookup.get_by_key(hsh)
			end
			ret
		end
		
		# takes an array of hashes and created a query where all conditions 
		# set by the array are OR-ed and returned. 
		def self.batch_query(arr_of_hsh, model, fields = nil, batch_size = 100)
			ret = []
			arr_of_hsh = [arr_of_hsh] unless arr_of_hsh.is_a?(Array)
			## try to determine table name and fields
			if not model.is_a?(ActiveRecord::Relation)
				begin Kernel.const_get(model.to_s.capitalize.singularize.camelcase)
					model = Kernel.const_get(model.to_s.capitalize.singularize.camelcase)
					tbl = model.table_name + "."
					fields = model.attribute_names if fields.nil?
				rescue NameError
					tbl = model.to_s.underscore.downcase.pluralize + "."
					fields = ActiveRecord::Base.connection.execute("DESCRIBE #{tbl[0..-2]}").each(as: :hash).map{|rec| rec["Field"] } if fields.nil?
				end
			else
				tbl = ""
				fields = "*"
			end
			
			arr_of_hsh.each_slice(batch_size) do |batch|
				## create statement
				conditions = batch.map{|hsh|
					cnd = hsh.map{|field, val|
						if val.is_a?(String) then
							"#{tbl}#{field} = '#{val}'"
						elsif val.nil? then
							"#{tbl}#{field} IS NULL"
						else
							"#{tbl}#{field} = #{val}"
						end 
					}
					"(#{cnd.join(" AND ")})"
				}.join(" OR ")
				
				## select from the object or select from the connection and return an array
				if not model.is_a?(String)
					ret << model.where(conditions).select(fields)
				else
					ret << ActiveRecord::Base.connection.execute("SELECT #{fields.join(",")} FROM #{tbl[0..-2]} WHERE #{conditions}").each(as: :hash)
				end
			end
			ret.flatten!
			ret
		end
		
		def self.mass_insert(ar_objs, return_inserted_objects = false, batch_size = 10000, model = nil, trustme = true, fast = !ActiveRecord::Base.connection_config[:socket].nil?)
			ar_objs = [ar_objs] unless ar_objs.is_a?(Array)

			ar_objs.reject!{|x| x.nil?}
			return ar_objs if ar_objs.size == 0
			
			if !trustme
				if model.nil? then
					## check if array only contains ActiveRecord objects
					raise ArgumentError.new "not all elements are ActiveRecords" unless ar_objs.all?{|ar| ar.is_a?(ActiveRecord::Base)}
				else
					raise ArgumentError.new "not all elements are attribute-value pairs" unless ar_objs.all?{|ar| ar.is_a?(ActiveRecord::Base) || ar.is_a?(Hash)}
				end
				## check if all array elements belong to the same class
				raise ArgumentError.new "not all elements are the same class (#{ar_objs.map(&:class).uniq.sort.join(",")})" unless ar_objs.all?{|ar| ar.is_a?(ar_objs[0].class)}
			end
			model = ar_objs.first.class if model.nil?
			table = model.table_name
			columns = model.attribute_names
			values = []
			model.transaction do
				ar_objs.each do |obj|
					next if obj.is_a?(ActiveRecord::Base) && obj.persisted? ## skip objects that are already in the database
					ins_statement = get_insert_statement(obj, model)
					# values.push("(#{ins_statement[:values]})")
					values.push(ins_statement[:values])
					
					if values.size >= batch_size then
						if (!fast)
							do_mass_insert(model, table, columns, values)
						else
							do_mass_insert_fast(model, table, columns, values)
						end
						# sql_mass_insert(table, columns, values)
						values = []
					end
				end
				if values.size > 0 then
					if (!fast)
						do_mass_insert(model, table, columns, values)
					else
						do_mass_insert_fast(model, table, columns, values)
					end
				end
			end
			## retrieve the latest N object from the table, because those were the insersts that we just did
			if return_inserted_objects then
				ret = model.last(ar_objs.size)
				ret = Hash[ar_objs.each_with_index.map{|arobj, i|
					[arobj, ret[i]]
				}]
			else
				ret = []
			end
			ret
		end
		
		def self.sql_mass_insert(table, columns, values, connection = ActiveRecord::Base.connection)
			begin 
				values = values.values if values.is_a?(Hash)
				ins_values = values.map{|v|
					v = [v] unless v.is_a?(Array)
					# sanitize
					v = v.map{|vraw|
						ActiveRecord::Base::sanitize(vraw)
					}
					# surround with brackets
					"(#{v.join(",")})" 
				}
				ActiveRecord::Base.transaction do 
					connection.execute("INSERT INTO #{table} (#{columns.map{|c| "`#{c}`"}.join(",")}) VALUES #{ins_values.join(",")}")
				end
			rescue ActiveRecord::RecordNotUnique => e
				puts "At least one record violates a uniqueness constraint!"
				raise e
			end
		end
		
private
		# uses LOAD DATA to mass insert the data
		def self.do_mass_insert_fast(model, table, columns, values, local=(ActiveRecord::Base.connection_config[:socket].nil?))
			# create temp file
			fout = File.new(File.join(Rails.root, "tmp", "last_mass_insert_#{Time.now.to_f}.csv"), "w+")
			values.each do |v|
				fout.write("#{v}\n")
			end
			fout.close
			begin 
				model.connection.execute("LOAD DATA#{(local)?" LOCAL ":" "}INFILE '#{fout.path}' INTO TABLE #{table} FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY \"'\" (#{columns.map{|c| "`#{c}`"}.join(",")})")
			rescue ActiveRecord::RecordNotUnique => e
				puts "One record is not unique I try to determine this record for you - which is a terrible idea btw..."
				raise e
			end
			FileUtils.rm(fout.path)
			return true
		end
		
		def self.do_mass_insert(model, table, columns, values)
			begin 
				model.connection.execute("INSERT INTO #{table} (#{columns.map{|c| "`#{c}`"}.join(",")}) VALUES #{values.map{|v| "(#{v})"}.join(",")}")
			rescue ActiveRecord::RecordNotUnique => e
				puts "One record is not unique I try to determine this record for you - which is a terrible idea btw..."
				raise e
			end
			return true
		end

		def self.get_insert_statement(obj, model = obj.class)
			# model = obj.class
			table = model.table_name
			columns = model.attribute_names
			colvalus = []
			colvalus = columns.map do |colname|
				# colval = obj.send(colname.to_sym)
				colval = (obj.send("[]", colname.to_sym) || obj.send("[]", colname.to_s))
				## handle standard time stamps
				if ["created_at", "updated_at"].include?(colname) then
					if colval.nil? then
						colval = Time.now.strftime('%Y-%m-%d %H:%M:%S')
					end
				end
				if colval.is_a?(Array) or colval.is_a?(Hash)
					colval = colval.to_yaml 
				end
				colval
			end
			begin 
				sanitized_value_string = ActiveRecord::Base.__send__(:sanitize_sql, [(["?"]*colvalus.size).join(","), colvalus].flatten(1), '')
			rescue ActiveRecord::PreparedStatementInvalid => e
				p "ERROR in get_insert_statement..."
				p colvalus
				p colvalus.size
				p [(["?"]*colvalus.size).join(","), colvalus].flatten(1)
				raise e
			end
			
			return(
				{
					table: table,
					columns: columns,
					values: sanitized_value_string
				}
			)
			
		end
		
	end
end
