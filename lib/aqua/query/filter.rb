class Filter < Aqua
	
	attr_reader :filter_method, :name, :label, :organism, 
							:requirements, :tool, :checked, :collection_method, 
							:add_requirements, :query, :query_name
	
	def self.create_filter_for(queryklass, queryname, opts)
		Aqua.log_warning("Filter #{opts[:name]} it NOT ACTIVE") unless opts[:active].nil? or opts[:active] == true
		return false unless opts[:active].nil? or opts[:active] == true
		f = self.create(opts, queryklass, queryname)
		queryklass.register_filter(queryname, f)
	end
	
	def self.create(opts, qklass, queryname)
		raise ":filter_method required for filter" if opts[:filter_method].nil?
		opts[:label] = "#{opts[:tool]}:#{opts[:name]}" if (opts[:label].nil?)
		opts[:collection_method] = :get_collection if opts[:collection_method].nil?
		opts[:checked] = true if opts[:checked].nil?
		opts[:add_requirement] = true if opts[:add_requirement].nil?
		f = self.new(
									opts[:filter_method], 
									opts[:name], 
									opts[:label], 
									opts[:organism], 
									opts[:requires], 
									opts[:tool], 
									opts[:checked], 
									opts[:collection_method],
									opts[:add_requirement],
									qklass,
									queryname
		)
		f
	end
	
	def self.create_batch_filter(klass, attributes)
		attributes = [attributes] unless attributes.is_a?(Array)
		attributes.each do |attribute_name|
			query_name = QueryBatch.get_qname(klass, attribute_name)
			fname = "#{klass.table_name}.#{attribute_name}"
			create_filter_for QueryBatch, query_name,
							  name: fname,
							  label: "Batch filter #{fname}",
							  filter_method: :filter_by_query_type,
							  collection_method: nil,
							  organism: [organisms(:human), organisms(:mouse)],
							  checked: true,
							  requires: {
									klass => attribute_name
								},
							  tool: klass
		end
	end
	
	
	def self.fkey(name)
		sprintf("%s:%s", self.name.underscore, name)
	end
	
	def fkey()
		self.class.fkey(self.name)
	end
	
	def applicable?(organismid = nil)
		if not organismid.nil?
			return false unless @organism.any?{|o| o.id == organismid}
		end
		return Aqua.is_applicable?(requirements) if 1 == 1
	end
	
	def self.meets_requirements?(method)
		conf = self.config
		requirements = conf[:requires]
		ret = true
		requirements.each do |model, methods|
			attrs = model.attribute_names
			ret = ret & methods.all?{|m| attrs.include?(m.to_s)}
		end
		ret
	end

	def get_collection(params)
		[{unknown: "not implemented"}]
	end
	
	def initialize(filter_method, name, label, organism, requirements, tool, checked = true, collection_method = :get_collection, add_requirement = true, qklass, qname)
		raise "Not a configured method" if filter_method.nil?
		@filter_method = filter_method
		@name = name.to_sym
		@label = label.to_s
		@organism = organism
		@requirements = requirements
		@tool = tool
		@checked = (checked.is_a?(String))?checked == "1":checked
		@collection_method = collection_method
		@add_requirements = add_requirement
		@query = qklass
		@query_name = qname
	end

	def filter(value, params, qinst)
		# self.send(@method, value)
		raise "FILTER not implemented for super class."
	end
	
	def list_panels(params)
		User.find(params[:user]).generic_gene_lists.map{|ggl|
			{
				id: ggl.id,
				name: ActionController::Base.helpers.sanitize(ggl.name),
				title: ActionController::Base.helpers.sanitize(ggl.title),
				description: ActionController::Base.helpers.sanitize(ggl.description),
				"#items" => ggl.items.count
			}
		}
	end
	
	def find_samples(params)
		exp = Experiment.find(params[:experiment])
		user = User.find(params[:user])
		exp_smpls = Hash[exp.samples.map{|s| [s.id, true]}]
		exp_smpls.default = false
		smpl_ids = (user.reviewable(Sample) + user.samples + exp.samples).map(&:id)
		smpls = Sample.where(id: smpl_ids)
			        .includes([:tags, :entity_group, :experiments, :institution, :entity => :tags, :specimen_probe => :tags, :vcf_file_nodata => :tags])
		smpls.sort!{|s1, s2|
			if exp_smpls[s1.id] && exp_smpls[s2.id] then
				s1.name <=> s2.name
			elsif exp_smpls[s1.id] || exp_smpls[s2.id]
				(exp_smpls[s1.id])?-1:1
			else
				s1.name <=> s2.name
			end
		}
		ret = smpls.map{|s|
			eg = (!s.entity_group.nil?)?(s.entity_group.name):("NA")
			ent = (!s.entity.nil?)?(s.entity.name):("NA")
			spec = (!s.specimen_probe.nil?)?(s.specimen_probe.name):("NA")
			smpl = s.name
			vcf = (!s.vcf_file_nodata.nil?)?(s.vcf_file_nodata.name):("NA")
			rec = {
				id: s.id,
				label: s.nickname,
				name: [eg, ent, spec, smpl, vcf].join("/")
			}
			rec["Entity.tags"] = (!s.entity.nil?)?(s.entity.tags.join(" | ")):("NA")
			rec["Specimen.tags"] = (!s.specimen_probe.nil?)?(s.specimen_probe.tags.join(" | ")):("NA")
			rec["Sample.tags"] = (!s.nil?)?(s.tags.join(" | ")):("NA")
			rec["VcfFile.tags"] = (!s.vcf_file_nodata.nil?)?(s.vcf_file_nodata.tags.join(" | ")):("NA")
			rec
		}
	end
	

	
	def _reduce_to_accessible_samples(values, user)
		return values.map(&:to_i) & (user.reviewable(Sample).pluck("samples.id") + user.sample_ids + user.experiments.map(&:sample_ids)).flatten
		#return value if user.is_admin
		#usrsmpls = user.sample_ids
		#value.map(&:to_i).select{|x| usrsmpls.include?(x)}
	end
	
#	def required_columns()
#		reqcols = []
#		@requirements.each do |model, cols|
#			cols.each do |col|
#				if model.is_a?(Symbol) then
#					reqcols << "#{model}.#{col}"
#				else
#					reqcols << "#{model.table_name}.#{col}"
#				end
#			end
#		end
#		reqcols.sort.uniq
#	end
	
end

class SimpleFilter < Filter
	def filter(value, params = {}, qinst)
		# procs will be executed in class context, lambdas will be executed in instance context
		if (@filter_method.is_a?(Proc)) then
			if @filter_method.lambda? then
				if @filter_method.arity.to_i.abs == 1
					# @filter_method.call(value)
					self.instance_exec(value, &@filter_method)
				else
					# @filter_method.call(value, params)
					self.instance_exec(value, params, &@filter_method)
					
				end 
			else
				if @filter_method.arity.to_i.abs == 1
					lambda {|x| @filter_method.call(x)}.call(value)
				else
					lambda {|x,y| @filter_method.call(x,y)}.call(value, params)
				end
			end
		else
			if (method(@filter_method).arity.to_i.abs == 1) then
				self.send(@filter_method.to_sym, value)
			else
				self.send(@filter_method.to_sym, value, params)
			end
		end
	end
	
	def filter_by_query_type(value)
		qconf = self.query.configuration_for(self.query_name)
		if (qconf[:type] == :range_gt)
			filter_gt(value)
		elsif (qconf[:type] == :range_lt)
			filter_lt(value)
		elsif (qconf[:type] == :range_eq)
			filter_eq(value)
		elsif (qconf[:type] == :collection)
			filter_in(value)
		else
			raise "Filter type not recognized"
		end
	end
	
	def filter_in(value)
		ret = self.requirements.map{|klass, attrs|
			attrs = [attrs] unless attrs.is_a?(Array)
			attrs.map{ |attr|
				"#{klass.table_name}.#{attr} IN (#{value.join(",")})"
			}
		}.flatten.join(" AND ")
		return nil if ret.size == 0
		"(#{ret})"
	end
	
	def filter_eq(value)
		ret = self.requirements.map{|klass, attrs|
			attrs = [attrs] unless attrs.is_a?(Array)
			attrs.map{ |attr|
				"#{klass.table_name}.#{attr} = #{value}"
			}
		}.flatten.join(" AND ")
		return nil if ret.size == 0
		"(#{ret})"
	end
	
	def filter_gt(value)
		ret = self.requirements.map{|klass, attrs|
			attrs = [attrs] unless attrs.is_a?(Array)
			attrs.map{|attr|
				"#{klass.table_name}.#{attr} >= #{value}"
			}
		}.flatten.join(" AND ")
		return nil if ret.size == 0
		"(#{ret})"
	end
	
	def filter_lt(value)
		ret = self.requirements.map{|klass, attrs|
			attrs = [attrs] unless attrs.is_a?(Array)
			attrs.map{ |attr|
				"#{klass.table_name}.#{attr} <= #{value}"
			}
		}.flatten.join(" AND ")
		return nil if ret.size == 0
		"(#{ret})"
	end
end

class ComplexFilter < Filter
	def filter(arr, value, params = {}, qinst)
		# procs will be executed in class context, lambdas will be executed in instance context
		if (@filter_method.is_a?(Proc)) then
			if @filter_method.lambda? then
				if @filter_method.arity.to_i.abs == 2
					# @filter_method.call(arr, value)
					self.instance_exec(arr, value, &@filter_method)
				else
					# @filter_method.call(arr, value, params)
					self.instance_exec(arr, value, params, &@filter_method)
				end 
			else
				if @filter_method.arity.to_i.abs == 2
					lambda {@filter_method.call(arr, value)}
				else
					lambda {@filter_method.call(arr, value, params)}
				end
			end
		else
			if (method(@filter_method).arity.to_i.abs == 2) then
				self.send(@filter_method.to_sym, arr, value)
			else
				self.send(@filter_method.to_sym, arr, value, params)
			end
		end
		# raise "Query not implemented for super class."
	end
end
