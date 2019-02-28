# == Description
# The Annotation module implements all neccessary methods to register and manage new
# annotation tools as well as handle other more generic tasks. 
class Annotation < Aqua

	# TODO: It would be nice to have a pre-load hook in the classes that is executed when the module is loaded
	#       This would give the opportunity to copy the annotation databases to a RAM disk and use this for improved performance

	# TODO: If a subcalss overwrites @@VCFPARSER this gets messy. This should be cleaned up at some point.
	@@VCFPARSER = Vcf.new()
	@VCFHEADER = []
	
	def self.all_supporting_organism(organismid)
		ret = []
		Aqua.annotations.each do |klass, conf|
			d "#{klass} supports #{conf[:organism].size} organisms - #{conf[:organism].map{|o| o.id}.join(",")}"
			ret << klass if conf[:organism].any?{|o|
				o.id == organismid
			}
		end
		ret
	end
	
	def self.register_tool(opts)
		Aqua.log_warning("ANNOTATION #{opts[:label]} is NOT ACTIVE") unless opts[:active].nil? or opts[:active] == true
		return false unless opts[:active].nil? or opts[:active] == true
		raise "#{self.name} does not provide a model." if (opts[:model] || []).size == 0
		raise "Only one model may be provided." if opts[:model].size > 1
		raise "Tool doesn't supports any mutation type [snp, indel, cnv]" if opts[:supports].nil?
		opts[:supports] = [opts[:supports]] unless opts[:supports].is_a?(Array)
		raise "Tool #{self.name} #{opts[:supports].join(",")} supported mutation type not recognized [snp, indel, cnv]" unless opts[:supports].all?{|x| [:snp, :indel, :cnv, :none].include?(x.to_sym)}
		opts[:tool] = self
		opts[:type] = :annotation if opts[:type].nil?
		# Annotation.configure(self.name.underscore.to_sym, opts)
		self.register_annotation(self, opts)
	end
	
	# find a tool klass by classname or tool name
	def self.find_tool(tool_name)
		ret = nil 
		Aqua.annotations.each do |toolklass, opts|
			if (tool_name.to_sym == toolklass.name.underscore.to_sym) then
				ret = toolklass
				break
			elsif (tool_name.to_sym == opts[:name].to_sym) then
				ret = toolklass
				break
			end
		end
		ret
	end

	def self.organism(tool = self)
		tool.configuration[:organism]
	end
	
	def self.tool_name(tool = self)
		tool = Annotation.find_tool(tool) if tool.is_a?(Symbol)
		tool = Annotation.find_tool(tool.to_sym) if tool.is_a?(String)
		tool.configuration[:name]
	end
	
	# get the model of a tool
	def self.model(tool = self)
		return nil if tool.configuration.nil?
		return nil if tool.configuration[:model].nil?
		if tool.configuration[:model].is_a?(Hash) then 
			tool.configuration[:model].keys.first
		elsif tool.configuration[:model].is_a?(Array) then
			tool.configuration[:model].first
		else
			tool.configuration[:model]
		end
	end
	
	# get all required associations
	def self.associations(tool = self)
		assocs = tool.configuration[:model].values.first
		model = tool.model
		allassocs = model.reflect_on_all_associations().select{|a| assocs.include?(a.name)}
		allassocs
	end
	
#	### I dont thinks this is required anywhere....11. Jan. 2016
#	# add_joins adds a JOIN statement to the scope for every association that is associated with the model.
#	def self.add_joins(scope, organismid)
#		return scope if model.nil? # in case no base model exists
#		modeltbl = model.table_name
#		associations = self.associations
#		scope = scope.joins("INNER JOIN #{modeltbl} ON (#{modeltbl}.variation_id = variation_calls.variation_id AND #{modeltbl}.organism_id = #{organismid})")
#		if associations.size > 0 then
#			associations.each do |assoc|
#				# in case of has_and_belongs_to_many associations
#				if (!assoc.options[:join_table].nil?) then
#					assoctbl = assoc.options[:join_table]
#					jointbl = assoc.plural_name
#					forkey = (assoc.foreign_key || assoc.options[:foreign_key])
#					assocforkey = (assoc.association_foreign_key || assoc.options[:association_foreign_key])
#					# add join to n:m table
#					scope = _add_join(scope, modeltbl, assoctbl, "id", forkey)
#					# add join from n:m to target
#					scope = _add_join(scope, assoctbl, jointbl, assocforkey, "id")
#				else
#					jointbl = assoc.plural_name
#					primkey = (assoc.options[:primary_key] || "#{assoc.name}_id")
#					forkey = (assoc.options[:foreign_key] || "id")
#					scope = _add_join(scope, modeltbl, jointbl, primkey, forkey, organismid)
#				end
#			end
#		end
#		scope
#	end
	
#	def self._add_join(scope, tbl, jointbl, key1 = "id", key2 = "id", organismid = nil)
#		if organismid.nil? then
#			scope.joins("INNER JOIN #{jointbl} ON (#{tbl}.#{key1} = #{jointbl}.#{key2})")
#		else
#			scope.joins("INNER JOIN #{jointbl} ON (#{tbl}.#{key1} = #{jointbl}.#{key2} AND #{jointbl}.organism_id = #{organismid})")
#		end
#	end
	
	# Returns true if all requirements of an Annotation-Tool are met. 
	# This includes: 
	#  * The model given by the :model configuration attribute exists
	#  * The model has a variation_id column
	#  * The associations given by the :model configuration also exist.
	# See register_tool for more details on the configurations.
	def self.satisfied?()
		tool = self
		conf = tool.configuration
		models = (conf[:model] || conf[:models] || conf["model"] || conf["models"])
		
		is_satisfied = models.all? do |model, assocs|
			# check if model exists
			ret = ActiveRecord::Base.subclasses.map(&:name).any?{|m| m.to_s.underscore == model.to_s.underscore}
			# model has a variation_id column?
			ret = model.attribute_names.any?{|a| a.to_s == "variation_id"} if ret
			# model has a organism_id column?
			ret = model.attribute_names.any?{|a| a.to_s == "organism_id"} if ret
			# check if model has association to join tables
			if (!assocs.nil?)
				real_assocs = model.reflect_on_all_associations().map(&:class_name)
				ret = assocs.all?{|a| real_assocs.include?(a.name.to_s) } if ret
			end
			ret
		end
		
		is_satisfied
	end

	def self.get_requirements(previous_requirements = [])
		if previous_requirements.include?(self)
			raise "Dependency cycle detected #{self.name}=>#{previous_requirements.map(&:name).join("=>")}"
		end
		# check requirements
		ret = []
		opts = self.configuration
		reqs = (opts[:requires] || opts["requires"] || opts[:requirements] || opts["requirements"])
		if !reqs.nil?
			reqs = (reqs.keys + reqs.values).flatten if reqs.is_a?(Hash)
			reqs = [reqs] unless reqs.is_a?(Array)
			raise "Please provide requirements as Strings (#{self.name})" unless reqs.all?{|x| x.is_a?(String)}
			reqs.select!{|req| Annotation.descendants.map(&:name).include?(req)}
			ret = reqs.map{|x| Kernel.const_get(x.to_sym)}
			ret = ret + ret.map{|t|
				t.get_requirements(([self] + previous_requirements).flatten)
			}
		end
		(ret + previous_requirements).uniq.flatten - [self]
	end

	def self.meets_all_requirements?
		ret = false
		opts = self.configuration
		reqs = (opts[:requires] || opts["requires"] || opts[:requirements] || opts["requirements"])
		if !reqs.nil?
			reqs = (reqs.keys + reqs.values).flatten if reqs.is_a?(Hash)
			reqs = [reqs] unless reqs.is_a?(Array)
			reqs.select!{|req| Annotation.descendants.include?(req)}
			ret = reqs.all?(&:satisfied?)
		else
			ret = true
		end
		ret
	end

	# By default this method returns the satisfied value - but it can be overwritten by Annotation Subclasses to check
	# whether the pre-requisists are met for the tool (such as: binaries are available etc.)
	def self.ready?()
		return self.satisfied?
	end
	
	def self.ready_machines()
		asa = AquaStatusAnnotation.get("ready", "#{self.name}/#{self.configuration[:label]}")
		machines = YAML.load(asa.value.to_s)
		machines = [] if machines == false
		machines
	end
	
	def self.set_ready_maschines(machines)
		AquaStatusAnnotation.set("ready", "#{self.name}/#{self.configuration[:label]}", machines.uniq.to_yaml)
	end
	
	def self.track_readiness()
		# first check if the machine already satisfies the tool
		machines = ready_machines()
		is_ready = ready?
		if is_ready then
			machines << Socket.gethostname
		else
			machines.reject!{|host| host == Socket.gethostname}
		end
		set_ready_maschines(machines.sort.uniq)
		is_ready
	end
	
	def self.type
		return self.configuration[:type]
	end
	
	# Determine if a variation was annotated with a given tool
	def self.was_annotated?(varid, organism_id, tool = nil)
		tool = self if tool.nil? #Annotation.load_configuration(self.name.underscore.to_sym)[:tool] if tool.nil?
		conf = tool.configuration
		model = self.model
		themodel.exists?(variation_id: varid, organism_id: organism_id)
	end
	
	# Find the subset of varids that were annotated with tool
	def self.find_annotated(varids, organism_id)
		find_annotations(varids, organism_id).pluck(:variation_id)
	end
	
	# Find the subset of varids that were annotated with tool
	def self.find_annotations(varids, organism_id)
		tool = self
		conf = tool.configuration
		themodel = self.model
		themodel.where(variation_id: varids, organism_id: organism_id)
	end
	
	def self.create(opts)
		self.new(opts)
	end
	
	def initialize(opts)
		@VCFHEADER = {}
	end
	
	def self.vcf_files(state = "OK", tool = self)
		
		vcfids = AquaStatusAnnotation
							.where(type: "AquaStatusAnnotation")
							.where(category: "vcf_file")
							.where(source: "#{tool.name}/#{tool.configuration[:label]}")
		vcfids = vcfids.where(value: state) if !state.nil?
		vcfids = vcfids.pluck(:xref_id).reject(&:nil?)
		if (vcfids.size > 0) then
			#VcfFile.nodata.find(vcfids)
			VcfFile.nodata.where("vcf_files.id" => vcfids)
		else
			[]
		end
	end
	
	def self.get_vcf_annotation_status(vcfid, tool = self)
		vcfid = vcfid.id if vcfid.is_a?(VcfFile)
		vcf = VcfFile.select([:id, :name, :organism_id]).find(vcfid)
		
		# find existing
		asa = AquaStatusAnnotation.find_or_create_by_xref_id_and_type_and_category_and_source(vcfid, "AquaStatusAnnotation", "vcf_file", "#{tool.name}/#{tool.configuration[:label]}")
		# check if the tool is applicable to the vcf file
		if !tool.organism.map(&:id).include?(vcf.organism_id) then
			#asa.update_attribute(:value, "NOTAPPLICABLE")
			asa.not_applicable_annotation
		elsif !tool.configuration[:supports].any?{|mut_type| vcf.class.supports.include?(mut_type)} then
			#asa.update_attribute(:value, "NOTAPPLICABLE")
			asa.not_applicable_annotation
		end
		asa
	end
	
	def get_vcf_annotation_status(vcfid)
		self.class.get_vcf_annotation_status(vcfid, self.class)
	end
	
	def self.set_vcf_annotation_status(vcfid, status, tool = self)
		asa = get_vcf_annotation_status(vcfid, tool)
		asa.value = status
		asa.save!
		asa
	end
	
	def set_vcf_annotation_status(vcfid, status)
		self.class.set_vcf_annotation_status(vcfid, status, self.class)
	end
	
	def self.vcf_annotation_completed?(vcfid, tool = self)
		asa = get_vcf_annotation_status(vcfid, self)
		asa.annotation_completed?
		#asa.value == "OK" || asa.value == "NOTAPPLICABLE"
	end
	
	def vcf_annotation_completed?(vcfid)
		self.get_vcf_annotation_status(vcfid, self.class)
	end
	
	def vcf_annotation_status_complete(vcfid)
		set_vcf_annotation_status(vcfid, "OK")
	end
	
	def vcf_annotation_status_revoke(vcfid)
		set_vcf_annotation_status(vcfid, "REVOKE")
	end
	
	# Executes perform_annotation and uses the result as a paramter for store. 
	def annotate_and_store(vcf_filepath, vcf)
		# perform annotaiton
		set_vcf_annotation_status(vcf, "PERFORM_ANNOTATION")
		result = perform_annotation(vcf_filepath, vcf)
		# store result
		set_vcf_annotation_status(vcf, "STORE")
		success = store(result, vcf)
		
		#if self.class.configuration(:quantiles)
		#	success = success & update_quantile_estimates(vcf.organism_id)
		#end
		if success then
			set_vcf_annotation_status(vcf, "OK")
		else
			set_vcf_annotation_status(vcf, "FAIL")
		end
		# raise ArgumentError.new("store() has to return true or false") unless success.is_a?(TrueClass) || success.is_a?(FalseClass)
		success
	end

	# This is where the acutal annotation happens. 
	def perform_annotation(vcf_filepath, vcf)
		raise "Not Implemented for super class."
	end
	
	# returns true/false
	# result holds whatever perform_annotation returns. A result filename is likely but not mandatory.
	def store(result, vcf)
		raise "Not Implemented for super class."
	end
	
	def self.update_quantile_estimates(organism_id, stop_after = 100000)
		return true if self.configuration(:quantiles).nil?
		success = true
		self.configuration(:quantiles).each do |model, attribute_and_direction|
			attribute_and_direction.each do |attribute, direction|
				success = success & update_quantile_estimates_for(model, attribute, direction, organism_id, stop_after)
			end
		end
		return success
	end
	
	def update_quantile_estimates(organism_id, stop_after = 100000)
		self.class.update_quantile_estimates(organism_id, stop_after)
	end
	
	def self.update_quantile_estimates_for(model, attribute, direction, organism_id, stop_after)
		# check if model + attribute + direction + organism quantile already exists
		aq = AquaQuantile.get_for(model, attribute, direction, organism_id)
		(aq.update_estimates(stop_after) || false)
	end
	
	def self.quantile_estimates(organism_id, attribute_to_get = nil)
		quantiles = []
		(self.configuration(:quantiles) || {}).each do |model, attribute_and_direction|
			attribute_and_direction.each do |attribute, direction|
				if attribute_to_get.nil? then
					quantiles << AquaQuantile.get_for(model, attribute, direction, organism_id)
				else
					return AquaQuantile.get_for(model, attribute, direction, organism_id) if attribute.to_s == attribute_to_get.to_s
				end
			end
		end
		if !attribute_to_get.nil? then
			return nil
		end
		quantiles
	end
	
	def quantile_estimates(organism_id, attribute_to_get = nil)
		self.class.quantile_estimates(organism_id, attribute_to_get)
	end
	
	# Parsed a VCF line using Vcf gem. 
	# If a header is detected by a ##-prefix the header is also parsed and stored in @VCFHEADER for later used.
	def parse_vcf(line, &block)
		if line[0..1] == "##" then
			type, val = line.split("=", 2)
			type.gsub!(/[#=]/, "")
			val.strip!
			@VCFHEADER[type] = {} if @VCFHEADER[type].nil?
			if (val[0] == "<") then
				fields = val.scan(/<(ID=.*?,)|(Number=.*?,)|(Type=.*?,)|(Description=".*?")>/).flatten.reject(&:nil?)
				fieldhsh = Hash[fields.map{|f| 
					ret = f.split("=", 2)
					ret[1].gsub!(/,$/, "")
					ret[1] = ret[1].gsub(/^['""]/, "").gsub(/['""]$/, "")
					ret
				}]
				fieldhsh["ID"] = "tag" if fieldhsh["ID"].nil?
				@VCFHEADER[type][fieldhsh["ID"]] = fieldhsh
			else
				description = val.gsub(/^['""]/, "").gsub(/['""]$/, "")
				@VCFHEADER[type] = description
			end
		else
			self.class.parse_vcf(line, &block)
		end
	end
	
	# Parses a VCF line into a Hash and yield it to the given block if neccessary.
	#      {
	#          chrom: "1",
	#          chr: "1",
	#          pos: 2,
	#          ref: "A",
	#          alt: "G",
	#          qual: 100,
	#          id: "rs123",
	#          fiter: "PASS",
	#          format: "FO:RM:AT:ST:RI:NG",
	#          info: {TAG1="Value1", TAG2="VALUE2"...},
	#          samples: {
	#                     sample1 => {FO: 1, RM: 2, AT: 3, ST: "ASD", RI: 123, NG: "nonsense"},
	#                     sample2 => {FO: 10, RM: 22, AT: 33, ST: "wasd", RI: 333, NG: "example"},
	#                     ...
	#                    },
	#      }
	# The keys of each sample elements corresponds to the fields given by the FORMAT attribute. 
	# A block can be given that is executed if the parse_line call is true.
	def self.parse_vcf(line, &block)
		ret = @@VCFPARSER.parse_line(line)
		if ret == true then
			ret = Hash[
				[:chrom, :pos, :id, :ref, :alt, :qual, :filter, :format, :info, :samples].map{|attr|
					[attr, @@VCFPARSER.send(attr)]
				}
			]
			ret[:chr] = ret[:chrom]
		end
		if block_given? and (not ret == false) then
			yield ret
		else
			ret
		end
	end

	# sorts a list of tools by their requirements
	# uses the normal sort function - should probably use a DFS, but this should work as well
	def self.sort_by_requirements(tools)
		sorted_tools = []
		while (tools.size > 0)
			t = tools.delete_at(0)
			r = t.get_requirements
			# check if the sorted tools meets all requirements
			if !r.all?{|x| sorted_tools.include?(x)} then
				tools += [r, t].flatten
			else
				sorted_tools << t unless sorted_tools.include?(t)
			end
		end
		sorted_tools
	end



end
