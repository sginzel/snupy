# == Description
# This module contains all utility functions that have a generic purpose and are not linked to a class
## http://stackoverflow.com/questions/3356742/best-way-to-load-module-class-from-lib-folder-in-rails-3
## Read this link if you have problems on understanding why the directory structure is the way it is.
module SnupyAgain
	module Utils
		
		def self.snupy_const_get(const)
			const.to_s.split('::').inject(Object) do |mod, class_name|
			   mod.const_get(class_name)
			end
		end
		
		def zip(data)
			Zlib::Deflate.deflate(data, Zlib::BEST_COMPRESSION)
		end
		
		def unzip(data)
			Zlib::Inflate.inflate(data)
		end
		
		def self.subclasses
			return self.descendants if 1 == 1
			subclasses = []
			ObjectSpace.each_object(Module) do |m|
				subclasses << m if m.ancestors.include? self
			end
			subclasses
		end
		
		def self.load_directory(dir)
			files = Dir[dir]
			classes = []
			files.each do |file|
				next unless file =~ /.rb$/
				classtoload = file.gsub(Rails.root.to_s, "").gsub(/^extras\//, "").gsub(/.rb$/, "").camelcase
				# classes << Kernel.const_get(classtoload.to_sym)
				classes << eval(classtoload)
			end
			return classes
		end
		
		def self.scope_to_array(scope)
			return [] if scope.nil?
			## get all tablenames involved
			selecta = [scope.table_name, scope.select("*").joins_values]
			## flatten recursivly the join tables
			flatten = lambda {|r|
								(recurse = lambda {|v|
										if v.is_a?(Hash)
											v.to_a.map{|x| recurse.call(x)}.flatten
										elsif v.is_a?(Array)
											v.flatten.map{|x| recurse.call(x)}
										elsif v.class.ancestors.include?(Arel::Nodes::Node)
											[v.left.name, v.right.each.reject{|x| !x.is_a?(Arel::Table)}.map(&:table_name)].uniq
										elsif ActiveRecord::Base.descendants.include?(v)
											v.table_name
										else
											if (v.to_s =~ /(.*JOIN)(.*)(ON|USING)/) then
												v.to_s.scan(/(.*JOIN)(.*)(ON|USING)/).first[1].strip
											else
												v.to_s
											end
										end
									}).call(r)
								}
			selecta = flatten.call(selecta).flatten
			## from the extracted table names, determine if the table exist in its pluralized or singularized form
			all_tables = ActiveRecord::Base.connection.tables
			selecta.map!{|tblname|
				existing_table = tblname
				existing_table = tblname.pluralize if all_tables.include?(existing_table.pluralize) 
				existing_table
			}
			## determine the available columns for each table
			selecta = selecta.map{|tblname| [tblname, Arel::Table.new(tblname).columns.map(&:name)]}
			## create a select statement that contains all fields of all tables
			## as {tablename.columnname => value, tablename1.columnname1 => value1...}
			selecta = selecta.map{|tblname, columns|
				columns.map{|colname|
					"#{tblname}.#{colname} as `#{tblname}.#{colname}`"
				}
			}.flatten
			ret = ActiveRecord::Base.connection.exec_query(scope.select(selecta.join(",")).to_sql).to_hash
			ret
		end

		## This helper methods create ActiveRecord instances through a
		## array of hashes 
		def self.build_model_from_properties(model, properties)
		  if model.is_a?(Array) then
		    hsh = {}
		    model.each do |mdl|
		      hsh[mdl] = build_model_from_properties(mdl, properties)
		    end
		    return hsh
		  else
		  	if properties.is_a?(Hash)
		  		properties = [properties]
		  	end
		    if model.is_a?(Symbol) or model.is_a?(String) then
		      model = Kernel.const_get(model.to_s.capitalize.singularize)
		    end
  		  if properties.is_a?(Array) then
  		    arr = []
  		    primkey = "#{model.table_name}.#{model.primary_key}"
  		    if properties.all?{|prop| prop.include?(primkey)} then
  		    	primary_ids = properties.map{|prop| prop[primkey]}
  		    	return model.find(primary_ids)
  		    end
  		    properties.each do |prop|
  		      arr << build_model_from_properties(model, prop)
  		    end
          return arr
  		  else
  		    tbl = model.table_name
          mdl_props = properties.keys.select{|k,v|k =~ /^#{tbl}.*/}
          mdl_props = Hash[mdl_props.map{|k| [k.gsub(/^#{tbl}./, ""), properties[k]]}]
          if mdl_props.size > 0 then
	          if mdl_props.keys.include?(model.primary_key) then
	          	return model.find(mdl_props[model.primary_key])
	          end
	          return (model.where(mdl_props).first || model.new(mdl_props))
	        else
	        	return nil
	        end
  		  end
  		end
		end
	end
end