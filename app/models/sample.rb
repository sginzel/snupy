# == Description
# A Sample contains the variations calls from a single VCF file. Since there can be multiple Samples in VcfFile these sample have to be extracted from the VcfFiles (see VcfFile for details).
# It also hold additional information about the patient and the kind of data that was retrieved from the patient. For example a sample can be a tumor, germline or a generic control sample. This enables us to reuse control samples later.
# == Attributes
# [contact] This field contains information about who sequenced the samples. Unlike the contact person of the Experiment (which has many samples), this field should contain the name of the person who did the acutal lab work. This can be used later for quality control.
# [gender] Gener of the sample
# [ignorefilter] Should the FILTER column of the VCF be ignored? This is useful for control samples especially. 
# [name] A (if possible) unique name for the sample.
# [notes] Additional Notes.
# [patient] A gloabally unambigious patient key. One patient can have many samples. 
# [vcf_sample_name] Name of the column in the vcf file
# [vcf_file_id] Link to VcfFile
# [sample_type] Type of the sample. This can for example be Tumor, Germline, Pedigree or Control. 
class Sample < ActiveRecord::Base
	include SnupyAgain::ModelUtils
	include SnupyAgain::Taggable
	
	AVAILABLE_STATUS = %w(CREATED ENQUEUED IMPORT DONE)
	AVAILABLE_TYPE = %w(Unknown Tumor PID Germline Pedigree Exclusive)
	
	belongs_to :vcf_file,
						 class_name:  'VcfFile',
						 foreign_key: 'vcf_file_id',
						 readonly:    true,
						 select:
									  [:id, :contact, :filename, :md5checksum, :sample_names, :status, :institution_id, :name, :organism_id, :type, :filters, :updated_at, :created_at].map{|attr| "vcf_files.#{attr}"}

	belongs_to :specimen_probe, class_name: 'SpecimenProbe'
	has_one :entity, through: :specimen_probe, class_name: 'Entity'
#, uniq: true
	has_one :entity_group, through: :entity
	# this should be used when it is neccessary to avoid joins.
	belongs_to :entity_association, foreign_key: :entity_id, class_name: 'Entity', readonly: true
	belongs_to :entity_group_association, foreign_key: :entity_group_id, class_name: 'EntityGroup', readonly: true
	
	### tags
	has_and_belongs_to_many :sample_tags, class_name: 'Tag', join_table: :tag_has_objects, foreign_key: :object_id,
							:conditions               => {'tags.object_type' => 'Sample'}
	has_many :entity_tags, class_name: 'Tag', through: :entity
	has_many :specimen_probe_tags, class_name: 'Tag', through: :specimen_probe
	has_many :vcf_file_tags, class_name: 'Tag', through: :vcf_file_nodata
	
	
	# has_and_belongs_to_many :sample_tags, join_table: :sample_has_sample_tag
	has_and_belongs_to_many :users, join_table: :sample_has_users
	has_and_belongs_to_many :experiments, join_table: :sample_has_experiments
	has_many :variations, through: :variation_calls, inverse_of: :samples
	has_many :regions, through: :variations, inverse_of: :samples
	has_many :variation_calls, inverse_of: :sample, dependent: :delete_all
	#has_many :variation_annotations, through: :variations, inverse_of: :samples
	#has_many :genetic_elements, through: :variation_annotations, inverse_of: :samples
	#has_many :consequences, through: :variation_annotations, inverse_of: :samples
	# has_many :institutions, through: :users, :uniq => true
	# has_one :institution, through: :vcf_file, inverse_of: :samples
	# TODO add has_many affiliations and has_many users trought institutions
	
	has_many :sample_statistics, dependent: :delete_all, foreign_key: :record_id, inverse_of: :sample

	belongs_to :vcf_file_nodata, 
							class_name:  'VcfFile',
							foreign_key: 'vcf_file_id',
							readonly:    true,
							select:
										 [:id, :contact, :filename, :md5checksum, :sample_names, :status, :institution_id, :name, :organism_id, :type, :filters].map{|attr| "vcf_files.#{attr}"}
	belongs_to :vcf_file_full,
						 class_name:  'VcfFile',
						 foreign_key: 'vcf_file_id'
	has_one :institution, through: :vcf_file_nodata
	has_one :organism, through: :vcf_file_nodata, source: :organism


	attr_accessible :contact, :gender, :ignorefilter, :name, :nickname, 
									:notes, :patient, :vcf_sample_name, :vcf_file_id, 
									:sample_type, :min_read_depth, :info_matches, :status,
									:filters, :specimen_probe_id,
									:entity_id, :entity_group_id # read only associations
	
	before_destroy :destroy_has_and_belongs_to_many_relations
	before_save :update_sample_annotation_associations
	
	## accessors make it possible to set attributes from the controller if the model has changed
	attr_accessor :updating_vcf_file
	
	# == Description
	# Before saving a Sample record we need to check if the given VcfFile exists and 
	# if the given Sample.vcf_sample_name can be found in that VcfFile
	class SampleNameValidator < ActiveModel::Validator
		def validate(record)
			# if (!record.vcf_file_id.nil?) && (record.should_validate_vcf_file) then
				vcf_file = VcfFile.nodata.find(record.vcf_file_id)
				# check if the specimen we want to link ourselves to belongs to the same institution
				if !record.specimen_probe.nil? then
					if record.specimen_probe.institution.id != vcf_file.institution_id then
						record.errors[:base] << 'Sample and specimen do not belong to the same institution'
					end
				end
				
				## check if vcf_files_sample name is in the vcf
				vcf_file_smpls = vcf_file.sample_names
				if !vcf_file_smpls.include?(record.vcf_sample_name) or record.vcf_sample_name.nil? then
					record.errors[:base] << 'Not a valid vcf sample name'
				end
				# make sure all selected filters are available in the linked vcf file
				# if the ignore_filter attribute is set all filters are available
				vcf_filters = YAML.load(vcf_file.filters).keys
				# there was a phase where every combination of filters was stored. this is not practical
				vcf_filters = vcf_filters.map{|f| f.to_s.split(';')}.flatten
				record.filters = vcf_filters if record.ignorefilter
				record.filters = record.filters.join(',') if record.filters.is_a?(Array)
				if !record.filters.split(/[,;]/).uniq.all?{|fval| vcf_filters.include?(fval)} then
					wrong_filters = record.filters.split(/[,;]/).uniq.select{|fval| !vcf_filters.include?(fval)}
					record.errors[:base] << "Not all filters (#{record.filters}) found in VCFFile (#{vcf_filters.join(',')}) (WRONG: #{wrong_filters.join(', ')})"
				end
			# end
				# next, if the specimen_probe_id was set, then set the patient field to the name of the entity it is linked to
				if (!record.specimen_probe_id.nil?) then
					record.patient = ((record.entity || Entity.new).name || record.patient)
				end
			true 
		end
	end

	validates_with SampleNameValidator

	def invalidate_aqua_query_cache
		long_jobs.destroy_all
	end
	
	def destroy_has_and_belongs_to_many_relations
		# when the sample is destroyed we also need to destroy the cached results for the experiments the sample is associated with. 
		# Because the query stores the variation_call.ids which dont exist anymore after destroying the sample
		long_jobs.destroy_all
		LongJob.where(method: :add_variation_calls, handle: self.id, status: 'ENQUEUED').destroy_all
		#experiments.each do |exp|
		#	exp.long_jobs.each do |job|
		#		params = YAML.load(job.parameter).first
		#		if params["samples"].include?(self.id.to_s) then
		#			job.destroy
		#		end
		#	end
		#end
		## this results in a deadlock when the sample is deleted as part of a job
		# LongJob.where(method: "add_variation_calls").where(handle: self.id.to_s).destroy_all
		users = []
		experiments = []
		sample_tags = []
	end
	
	def update_sample_annotation_associations
		if self.specimen_probe_id then
			# we cant use self.entity and self.entity_group here because I guess during the save process this is not set when the sample is first initilized
			spec = SpecimenProbe.find(self.specimen_probe_id)
			ent = spec.entity
			self.entity_id = spec.entity_id
			self.entity_group_id = ent.entity_group_id
		else
			self.entity_id = nil
			self.entity_group_id = nil
		end
		self
	end
	
	def long_jobs
		lj_ids = []
		experiments.each do |exp|
			exp.long_jobs.each do |job|
				params = YAML.load(job.parameter).first
				next if params.nil?
				if params['samples'].include?(self.id.to_s) then
					lj_ids << job.id
				end
			end
		end
		return LongJob.where(id: lj_ids)
	end
	
	def should_validate_vcf_file
		new_record? || updating_vcf_file || vcf_file_id_changed?
	end
	
	def statistics
		# SampleStatistic.where(type: "SampleStatistic", record_id: self.id)
		sample_statistics
	end
	
	def self.statistic_collectors
		SnupyAgain::StatisticCollector::Template.collectors('sample')
	end

	# TODO FIXME this should be fixed when sample annotation is in production
	def ready_to_query?()
		return true if 1 == 1
		#(self.status == "DONE") || 
		#(
		# before April first all samples will be queryable. Until then all samples must be associated to a specimen_probe
			Time.now < Time.new(2017, 04, 21) ||
			(
				self.status == 'DONE' &&
				!self.specimen_probe.nil? &&
				self.specimen_probe.queryable?
			)
		#)	 
	end
	
	def gender_coefficient
		sample = self
		stats = {
			id: sample.id,
			nickname: sample.nickname,
			name: sample.name
		}
		chromosome = {}
		#chromosome = {
		#	gonosome: {hom: 0.0, het: 0.0, cnt: 0.0}, 
		#	monosome: {hom: 0.0, het: 0.0, cnt: 0.0}
		#}
		total = {hom: 0.0, het: 0.0, cnt: 0.0}
		VariationCall.includes(:region).joins(:region)
		.where('sample_id' => sample.id)
		.each do |varcall|
			chr = varcall.region.name.upcase
			#chrclass = :gonosome
			#chrclass = :monosome if chr == "X" or chr == "Y"
			gt = varcall.gt
			chromosome[chr] = {hom: 0.0, het: 0.0} if chromosome[chr].nil?
			is_hom = gt.split(/[|\/]/)
			is_hom = is_hom[0] == is_hom[-1]
			mygt = (is_hom)?(:hom):(:het)
			chromosome[chr][mygt] += 1
			#chromosome[chrclass][mygt] += 1
			#chromosome[chrclass][:cnt] += 1
			total[mygt] += 1
			total[:cnt] += 1
		end
		# get average hom/het ratio over gonosomes
		gono_ratios     = chromosome.map{|chr, hom_het_cnt|
			if !(chr == 'X' or chr == 'Y' or chr == 'W' or chr == 'Z')
				hom_het_cnt[:hom]/(hom_het_cnt[:hom] + hom_het_cnt[:het])
			else
				nil
			end
		}.reject(&:nil?)
		gono_ratios = [] if gono_ratios.nil?
		chromosome["X"] = {hom: 0.0, het: 0.0} if chromosome["X"].nil?
		xhom_ratio = chromosome["X"][:hom].to_f/(chromosome["X"][:hom]+chromosome["X"][:het])
		xhom_degree = xhom_ratio / gono_ratios.to_scale.mean
		xhom_degree
	end
	
	def self.variation_calls(smplids)
		# TODO: Beim Projekt AllSamples passiert hier ein Fehler
		# NoMethodError (undefined methonild `id' for nil:NilClass):
		# app/models/sample.rb:107:in `map'
		# app/models/sample.rb:107:in `variation_calls'
		# app/controllers/experiments_controller.rb:346:in `query_details'
		# Das koennte darauf hinweisen, dass nicht alle samples einen organismus haben-was komisch wäre. 
		# Wahrscheinlicher ist, dass smplids nicht richtig übermittelt wird, weil es so viele sind 
		# könnte eine ID abgeschnitten werden, die nicht existiert und die dann den Fehler wirft.
		organisms = Sample.where(id: smplids).map(&:organism).uniq.map(&:id)
		VariationCall.joins(:sample)
								 .joins(variation: [:alteration, :region])
								 .joins(variation: {variation_annotations: [:genetic_element, :consequences, :loss_of_function]})
								 .where('samples.id' =>smplids)
								 .where('variation_annotations.organism_id' => organisms)
								 .includes(variation: [:region, :alteration])
								 .includes(variation: {variation_annotations: [:genetic_element, :consequences, :consequences, :loss_of_function]})
	end
	
	## this functions identifies and removes variations from the variation table that
	## were inserted by mistake
	def assure_variation_call_consistency(create_job = false)
		## because of the regular expression that is tested against the info field
		## of each entry we have no other choice but to call the add_variation_calls
		## function. Which removes all variations and adds them again
		if create_job == false then
			if self.status == 'DONE' then
				add_variation_calls
				return true
			end
			return false
		else
 			self.status = 'ENQUEUED'
			self.save!
			# TODO find a better way to set the correct user
			user = User.find_by_full_name(self.contact)
			if user.nil?
				username = self.contact
			else
				username = user.name
			end 
			long_job = LongJob.create_job({
				title:   "Extract #{self.name}",
				 handle: self,
				 method: :add_variation_calls,
				 user:   username,
				 queue:  'annotation'
			}, false)
			return long_job
		end
	end
	
	# This function add the variation calls of a sample from its VcfFile.
	# The variations are determined by querying the Region and Alteration one by one. This is not the most efficient way and should be changed in the future.
	# The function returns nil on success and an error message when an error occured.
	def add_variation_calls
		d "adding variation calls for #{self.id}"
		oldstatus = self.status
		self.status = 'IMPORT'
		self.save!
		if (	(oldstatus == 'DONE' || oldstatus == 'ENQUEUED')||
			 		!(self.variation_calls.first.nil?)
			 	) then
			## delete all statistics
			self.statistics.destroy_all
			
			## destroy the cached jobs
			self.invalidate_aqua_query_cache
			
			## delete all variation calls - fast!
			d 'old variation calls are deleted'
			varcallids = self.variation_calls.pluck(:id)
			Sample.transaction do 
				d "removing variation call tags for #{varcallids.size} variation calls"
				VariationCallTag.connection.execute("DELETE FROM variation_call_has_variation_call_tag WHERE variation_call_id IN (#{varcallids.join(',')})") if varcallids.size > 0
				d "removing #{varcallids.size} variation calls"
				VariationCall.connection.execute("DELETE FROM #{VariationCall.table_name} WHERE sample_id = #{self.id}")
			end
			# self.variation_calls.delete_all
			# self.status = "ENQUEUED"
		elsif oldstatus == 'IMPORT'
			return 'variation calls are currently being imported'
		elsif self.vcf_file_id.nil? or self.vcf_sample_name.nil?
			return 'no vcf file or sample name selected'
		elsif not Sample::AVAILABLE_STATUS.include?(oldstatus)
			return "variation calls cannot be added because the status (#{oldstatus}) is not valid"
		end
		
		vcffile = VcfFile.find(self.vcf_file_id)
		if vcffile.status.to_s != 'DONE' then
			# the VcfFile need to be annotated so we can be (semi-)sure it was a valid VcfFile
			return 'VcfFile was not annotated yet.'
		end
		vcfsamplename = self.vcf_sample_name
		
		d 'creating variation lookup'
		var_lookup = self.vcf_file_full.create_lookup
		
		varcall_attr = VariationCall.attribute_names.map(&:to_sym)
		varcall_buffer = []
		added_varcalls = Hash.new(false)
		num_varcalls = 0
		
		# create filter hash
		passfilter = Hash.new(false)
		self.filters.split(',').each do |filterval|
			filterval.split(';').each do |f|
				passfilter[f] = true
			end
		end
		
		d "load variation calls from VcfFile (sample: #{vcfsamplename}, filter: #{self.filters})"
		vcffile.get_variation_calls(vcfsamplename) do |varcall|
			if not self.ignorefilter then
				# next unless varcall[:filter].upcase == "PASS" or varcall[:filter] == "."
				next unless varcall[:filter].split(';').any?{|fvalue| passfilter[fvalue]}
			end
			
			if self.min_read_depth > 0 then
				next unless varcall[:dp] >= self.min_read_depth
			end
			
			if self.info_matches.to_s != '' then
				conditions = self.info_matches.to_s.lines().map(&:strip).reject{|c| c.to_s == ''
				}
				next unless conditions.all?{|cond|
					if cond =~ /.*[<>=].*/ then
						cond = cond.gsub(' ', '')
						opstart = cond.index(/[<>=]/)
						opend = cond.index(/[<>=]/, opstart)
						op = cond[opstart..opend]
						field, val = [cond[0...opstart], cond[(opend+1)..-1]] #cond.split(/[<>=]/)
						field.strip!
						val.strip!
						case op
							when '=' then ( (varcall[:info][field].to_s.to_f == val.to_f) || (varcall[:info][field].to_s == val.to_s) )
							when '==' then ( (varcall[:info][field].to_s.to_f == val.to_f) || (varcall[:info][field].to_s == val.to_s) )
							when '>=' then (varcall[:info][field].to_s.to_f >= val.to_f)
							when '>' then (varcall[:info][field].to_s.to_f > val.to_f)
							when '=<' then (varcall[:info][field].to_s.to_f <= val.to_f)
							when '<' then (varcall[:info][field].to_s.to_f < val.to_f)
							else false
						end
					else # if no condition is found in this line handle as TAG
						!varcall[:info][cond].nil?
					end
				}
				# next unless varcall[:info] =~ Regexp.new(self.info_matches.to_s)
			end
			
			var = varcall[:var]
			variation = var_lookup[{chr: var[:chr], start: var[:start], stop: var[:stop], 
													ref:var[:ref], alt: var[:alt]}]
			raise "variation id not found for #{[var[:chr], var[:start], var[:stop], var[:ref], var[:alt]].join(':')}" if variation.nil?
			varid = variation.id
			
			vc = VariationCall.new()
			varcall_attr.each do |a|
				vc[a] = varcall[a] unless varcall[a].nil?
			end
			
			vc.variation_id = varid
			vc.sample_id = self.id
			
			varcall_buffer << vc if added_varcalls["#{self.id}:#{varid}:#{varcall[:dp]}:#{varcall[:gt]}"] == false 
			added_varcalls["#{self.id}:#{varid}:#{varcall[:dp]}:#{varcall[:gt]}"] = true
			
			num_varcalls = num_varcalls + 1
			## clear buffer
			if varcall_buffer.size >= 5000 then
				SnupyAgain::DatabaseUtils.mass_insert(varcall_buffer)
				varcall_buffer = []
			end
		end
		## clear buffer
		if varcall_buffer.size > 0 then
			SnupyAgain::DatabaseUtils.mass_insert(varcall_buffer)
		end
		self.status = :DONE
		self.save!
		## clear memory 
		var_lookup = nil
		tmp = nil
		vcffile = nil

		d "Refreshing statistics for ##{self.id}..."
		refresh_statistics
		 
		d "#{num_varcalls} variation calls added for sample ##{self.id}"
		return "#{num_varcalls} variation calls added for sample ##{self.id}"
	end

	def self.refresh_statistics(ids, statistics = nil)
		ids = [ids] unless ids.is_a?(Array)
		success = ids.all? do |id|
			smpl = Sample.find(id)
			smpl.refresh_statistics(statistics)
		end
		return success
	end

	def refresh_statistics(statistics = nil)
		statistics = Sample.statistic_collectors if statistics.nil?
		statistics = [statistics] unless statistics.is_a?(Array)
		## find all statistics collectors for sample
		collectors = SnupyAgain::StatisticCollector::Template.collectors('sample')
		collectors = collectors.select{|x| statistics.include?(x)} unless statistics.nil?
		collectors.map do |c|
			next unless c.auto_calculate
			existing = self.sample_statistics.select{|x| x.resource == c.to_s }
			if existing.size > 0 then
				existing.each do |ss|
					ss.destroy
				end
			end
			c.new(self).collect()
		end
	end
	
	# Iterate over VariationCalls using a sliding window
	# overlaps are not supported - yet
	def each_window(window_size = 1, chr = nil, &block)
		ret = []
		if chr.nil? then
			varcalls = self.variation_calls
									.includes(:region)
									.order('regions.name ASC', 'regions.start ASC', 'regions.stop ASC')
		else
			varcalls = self.variation_calls
									.includes(:region)
									.where('regions.name' => chr)
									.order('regions.name ASC', 'regions.start ASC', 'regions.stop ASC')
		end
		varcalls.sort!
		vc = varcalls.shift
		while varcalls.size > 0 do
			chr = vc.region.name
			pos = vc.region.start
			window = []
			stop = pos + window_size
			## search the last variation that is inside the window
			while vc.region.start < stop && vc.region.name == chr && varcalls.size > 0 do
				window << vc 
				vc = varcalls.shift
			end
			if block_given?
				yield window
			else
				ret << window
			end
			window = []
		end
		if not block_given?
			return ret
		end
	end
	
	# return the number of common variants
	# either absolute, or as a fraction
	def overlap(othrsmpl, type = :absolute, mindp = 0)
		
		return cosine_similarity(othrsmpl, mindp) if type == :cosine
		return weighted_cosine_similarity(othrsmpl, mindp) if type == :cosine_weighted
		
		myvars = variations.where("dp >= #{mindp}").where("filter = 'PASS'").pluck(:variation_id)
		othrvars = othrsmpl.variations.where("dp >= #{mindp}").where("filter = 'PASS'").pluck(:variation_id)
		num_overlap = (myvars & othrvars).size.to_f
		if type == :relative || type == :fraction then
			num_overlap = num_overlap / (myvars | othrvars).size.to_f
		end
		num_overlap
	end
	
	def cosine_similarity(othrsmpl, mindp = 0)
		baf1 = variation_call_bafs(true, mindp)
		baf2 = othrsmpl.variation_call_bafs(true, mindp)
		do_cosine_similarity(baf1, baf2, Hash.new(1))
	end
	
	def weighted_cosine_similarity(othrsmpl, mindp = 0)
		baf1 = self.variation_call_bafs(mindp)
		baf2 = othrsmpl.variation_call_bafs(mindp)
		weights = get_exac_weights(mindp)
		do_cosine_similarity(baf1, baf2, weights)
	end
	
	def relatedness_yang(othrsmpl, mindp = 0)
		raise 'Not implemented'
		records = Aqua.scope_to_array(VariationCall.where(sample_id: [self.id,othrsmpl.id]).select('variation_id, sample_id, gt, ref_reads, alt_reads'))
		# we need to estimate the average read depth for each variation 
		# as well as derive the alt allelefreq over all samples for that location
		# we can use the shared control samples to lay the foundation for the average read distribution
		## This SQL statement first calculates the average ref_reads, alt_reads and DP values BY specimen, so we don't count all the stuff twice
		## The outer Statement then calculates the averages
		## This can be used to calculate Xij of the Yang equation
		## THERE should also be an option to limit the query to the variations present in the two samples
		## The calculation should fail if less than 10 control samples can be identified
		### This estimation fails for positions where one variant in a shared control is homozygously mutated and 
		### not present in any other control. Wont this give a wrong impression? 
		### --> Use the specimen_probe_count as a measure of confidence?
		#### Maybe add the average DP to ref_reads for every specimen that does not carry the mutation? 
		#### Because if other specimen would carry a mutation at that location we would see it.
		##### 1) In order to do so we should calculate the properties of the read depth distribution. Shouldnt we? Or just use the average DP to the ref_reads?
		##### 2) The specimen_probe count is related to the statistical power, because we should give higher weights to sites where we have a solid allele frequency estimation
		# entities = Tag.where(value: "shared control").where(object_type: "Entity").first.objects
		control_ids = Tag.where(value: 'shared control').where(object_type: 'Entity').first.objects.joins(:samples).pluck('samples.id')
		## maybe the control ids should be extracted using .to_sql and make that a subquery with a sorted index to speed things up
		control_sql = Tag.where(value: 'shared control').where(object_type: 'Entity').first.objects.joins(:samples).select('samples.id').order('samples.id').to_sql
		sql = %(
			SELECT variation_id, AVG(avg_ref_by_spec) AS ref_reads, AVG(avg_alt_by_spec) AS alt_reads, AVG(avg_dp_by_spec) AS dp, COUNT(DISTINCT specimen_probe_id) as num_specimen FROM (
				SELECT specimen_probe_id, variation_id, AVG(ref_reads) AS avg_ref_by_spec, AVG(alt_reads) AS avg_alt_by_spec, AVG(dp) AS avg_dp_by_spec
				FROM variation_calls
				INNER JOIN samples ON (samples.id = sample_id)
				WHERE specimen_probe_id IS NOT NULL AND ref_reads > 0 AND alt_reads > 0 AND dp > 0 AND
				sample_id IN (
					#{control_sql}
				) AND
				variation_id IN (
					SELECT variation_id FROM variation_calls WHERE sample_id IN (#{self.id}, #{othrsmpl.id})
					ORDER BY variation_id
				)
				GROUP BY specimen_probe_id, variation_id
				ORDER BY variation_id
			) group_by_spec
			GROUP BY variation_id
		)  
		
	end
	
	def variation_call_bafs(as_hash = false, mindp = 0)
		k1 = mindp.to_s
		k2 = "-#{mindp.to_s}"
		@baf_cache = {} if @baf_cache.nil?
		if @baf_cache[k1].nil?
			@baf_cache[k1] = variation_calls.where(" dp > #{mindp} and (ref_reads > 0 or alt_reads > 0)").select('variation_calls.*, alt_reads/(ref_reads + alt_reads) as baf')
		end
		if as_hash then
			if @baf_cache[k2].nil? then
				@baf_cache[k2] = Hash[
					@baf_cache[k1].map{|vc|
						[vc.variation_id, vc.baf.to_f]
					}
				]
			end
			return @baf_cache[k2]
		end
		return @baf_cache[k1]
	end
	
	# use inversed frequency as weights
	def get_exac_weights(mindp = 0)
		baf = variation_call_bafs(true, mindp)
		@weight_cache = {} if @weight_cache.nil?
		if @weight_cache[mindp].nil? then
			weights = {}
			ActiveRecord::Base.logger.silence do
				baf.keys.each_slice(1000) do |varid_batch|
					result = ActiveRecord::Base.connection.execute(%{
						SELECT DISTINCT variation_id, IFNULL(exac_adj_maf, 0)
						FROM  #{Vep::Ensembl.table_name} #{Vep::Ensembl.aqua_table_alias}
						WHERE #{Vep::Ensembl.colname('variation_id')} IN (#{varid_batch.join(',')}) AND source = 'Ensembl' AND organism_id = #{self.organism.id}
					}).to_a
					result.each do |varid, maf|
						weights[varid] = 1.0-maf.to_f
					end
				end
			end
			@weight_cache[mindp] = weights
		end
		@weight_cache[mindp] 
	end
	
private
	
	# weightings as described in Zhou, Q., Rousseau, R., Yang, L. et al. Scientometrics (2012) 93: 787. doi:10.1007/s11192-012-0767-9
	def do_cosine_similarity(baf1, baf2, weights)
		common_vars = baf1.keys & baf2.keys
		zaehler = common_vars.map{|vid| 
			weights[vid].to_f * baf1[vid].to_f * baf2[vid].to_f 
		}.inject(:+).to_f
		nenner1 = common_vars.map{|vid| weights[vid].to_f * (baf1[vid].to_f ** 2) }.inject(:+).to_f
		nenner2 = common_vars.map{|vid| weights[vid].to_f * (baf2[vid].to_f ** 2) }.inject(:+).to_f
		return nil if zaehler.nil?
		return nil if nenner1.nil? or nenner2.nil?
		return (zaehler/(Math.sqrt(nenner1)*Math.sqrt(nenner2)))
	end
	
end

