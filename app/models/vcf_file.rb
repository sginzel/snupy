# == Description
# A VcfFile object represents and contains a complete File in VCF4.1 format. The content of the file is compressed and stored in the database.
# The object can be annotated by VEP. TODO In the future this annotation process should become more flexible, but for now this has to do it. 
# == Attributes
# [contact] Contact person for this VcfFile. Usually the person who is reponsible for the Variation call process
# [content] Gzipped content of the VCF File.
# [filename] Filename that was used when uploaded. 
# [md5checksum] Optional MD5 sum of the file that is uploaded. If it is not submitted, this contains the MD5Sum of the compressed content.
# [sample_names] CSV-List of samples in the file
# [status] Status can be any of <tt>[:CREATED, :ANNOTATIONPROCESS, :ADDVARIATION, :ADDANNOTATION, :DONE, :ERROR]</tt>
# [institution] A VcfFile belongs to an Institution
# [name] Globally unique name for the VcfFile. 
# == References
# * Institution
# * Sample
class VcfFile < ActiveRecord::Base
	# load("lib/vep/vep.rb")
	include SnupyAgain::Taggable
	extend ActiveSupport::DescendantsTracker
	
	AVAILABLE_STATUS = [:CREATED, :ADDVARIANTS, :ENQUEUED, :ANNOTATIONPROCESS,
											:INCOMPLETE, :ADDANNOTATION, :DONE, :ERROR]
	
	
	has_many :samples, dependent: :destroy
	has_many :specimen_probes, through: :samples, class_name: "SpecimenProbe"
	has_many :entities, through: :samples, class_name: "Entity", uniq: true
	has_many :variations, through: :samples
	has_many :variation_calls, through: :samples
	has_one  :vcf_file_index
	
	has_many :aqua_status_annotations,
	         foreign_key: "xref_id",
	         :conditions  => ['aqua_statuses.type = ? AND aqua_statuses.category = ? AND aqua_statuses.xref_id IS NOT NULL', AquaStatusAnnotation.name, "vcf_file"],
	         dependent:   :destroy #,
	#select: [:id, :contact, :filename, :md5checksum, :sample_names, :status, :institution_id, :name, :organism_id, :type, :filters, :updated_at, :created_at].map{|attr| "vcf_files.#{attr}"} +
	#						   AquaStatusAnnotation.attribute_names.map{|x| "#{AquaStatusAnnotation.table_name}.#{x}"}
	
	belongs_to :institution
	has_many :affiliations, through: :institution
	has_many :users, through: :affiliations, conditions: "roles LIKE '%_manager%' OR is_admin = 1"
	belongs_to :organism
	
	## tags
	has_and_belongs_to_many :vcf_file_tags, class_name: "Tag", join_table: :tag_has_objects, foreign_key: :object_id,
	                        :conditions                 => {"tags.object_type" => "VcfFile"}
	has_many :specimen_probe_tags, class_name: "Tag", through: :specimen_probes
	has_many :sample_tags, class_name: "Tag", through: :samples
	has_many :entity_tags, class_name: "Tag", through: :entities
	has_many :entity_group_tags, class_name: "Tag", through: :entity_groups
	
	attr_accessible :contact, :content, :filename,
	                :md5checksum, :sample_names,
	                :status, :institution, :institution_id,
	                :name, :organism_id, :type, :filters, :vcf_file_id
	validates_inclusion_of :status, :in => AVAILABLE_STATUS
	
	## accessors make it possible to set attributes from the controller if the model has changed
	attr_accessor :updating_content
	
	@variation_lookup = nil
	@_unzipped = nil
	
	scope :nodata, -> {
		select([:id, :contact, :filename, :md5checksum, :sample_names, :status, :institution_id, :name, :organism_id, :type, :filters, :updated_at, :created_at].map {|attr| "vcf_files.#{attr}"})
			.includes(:aqua_status_annotations)
		# select: [:id, :contact, :filename, :md5checksum, :sample_names, :status, :institution_id, :name, :organism_id, :type, :filters].map{|attr| "vcf_files.#{attr}"},
		# includes: :aqua_status_annotations
	}
	
	before_destroy :destroy_has_and_belongs_to_many_relations
	
	
	## Monkey patch Vcf class to include a [] accessor function
	class Vcf < Vcf
		def [](method_name)
			if self.respond_to?(method_name)
				self.send(method_name.to_sym)
			else
				nil
			end
		end
	end
	
	class VcfFileFormatValidator < ActiveModel::Validator
		include ActionView::Helpers::NumberHelper
		
		def validate(record)
			d "verifying vcfFile #{record.filename}"
			record.errors[:base] << "Institution #{record.institution_id} is not valid" if Institution.where(id: record.institution_id).size == 0
			if record.content.size >= 0 then
				## Check if we can identify samples names
				if record.get_sample_names_from_content.size == 0
					# record.errors[:base] << "no samples found for this VcfFile"
				else
					begin
						content = record.unzipped_content
						## Check if we can parse the file with the VCFReader
						lineno           = 0
						header           = []
						header_validated = false
						StringIO.open(content) do |io|
							io.each_line do |line|
							#content.split("\n").each do |line|
								lineno += 1
								## check if all lines start with [#0-9XZ]
								raise "Invalid format for one line in the file (has to match /^[#0-9XZM]/)" if !line =~ /^[#0-9XYM]/
								# vcfp.parse_line(line)
								# instead of calling parse_line - which would be better, because we use this to parse VCF files
								# we perform the same checks as parse_line does, but we dont have to create the result structure
								# and thus safe parsing time...
								header << line if line[0, 2] == "##"
								next if line[0] == "#"
								if !header_validated then
									record.validate_vcf_header(header) if record.respond_to?(:validate_vcf_header)
									header_validated = true
								end
								cols = line.chomp.split("\t", -1)
								raise "VCF lines must have at least 8 fields (line: #{lineno})" if cols.size < 8
								raise "If FORMAT column is given sample columns are required  (line: #{lineno})" if cols.size == 9
								num_format_fields = cols[8].split(":").size
								num_sample_fields = cols[9..-1].map {|sc| sc.split(":").size}
								if num_sample_fields.any? {|nsf| nsf > num_format_fields}
									raise "Malformated sample(s) at line: #{lineno}. Sample fields dont match FORMAT fields (#{num_sample_fields.join(",")} vs. #{num_format_fields})."
								end
								record.validate_vcf_line(cols) if record.respond_to?(:validate_vcf_line)
							end
						end
					rescue StandardError => e
						record.errors[:base] << "Could not parse variants, please check the file [INFO: Uploaded File Size is #{number_to_human_size(record.content.size)}] (#{e.message})"
					end
				end
			end
		end
	end
	## see: http://railscasts.com/episodes/41-conditional-validations?view=comments
	validates_with VcfFileFormatValidator, if: :should_validate_content
	
	def validate_vcf_header(header)

	end
	
	after_save :build_new_index
	
	def destroy_has_and_belongs_to_many_relations
		# AquaStatusAnnotation.where(id: self.aqua_annotation_status).destroy_all
		AquaStatusAnnotation.where(xref_id: self.id, category: "vcf_file").destroy_all
	end
	
	# TODO This should also include the re-import of all samples associated with the vcf file
	def build_new_index(force = false)
		if content_changed? || force
			@_unzipped = nil
			self.vcf_file_index.destroy unless self.vcf_file_index.nil?
			self.import_variants('SNuPy')
		end
	end
	
	# returns the status of the object
	def status
		read_attribute(:status).to_s.to_sym
	end
	
	# write the status of the object. This method also checks if the status to be set is valid.
	def status= (value)
		write_attribute(:status, value.to_s)
	end
	
	def self.supports
		[:snp, :indel, :cnv]
	end
	
	def annotate(tools = Annotation.all_supporting_organism(self.organism_id), user)
		if (!self.nil?) and (self.status == :CREATED or self.status == :INCOMPLETE) then
			vcf_annotater = AquaAnnotationProcess.new(self.id)
			long_job      = LongJob.create_job({
				                                   title:  "AQuA VCF #{self.name}",
				                                   handle: vcf_annotater,
				                                   method: :start,
				                                   user:   user,
				                                   queue:  "annotation"
			                                   }, false, tools)
			self.update_attribute(:status, :ENQUEUED) unless long_job.nil?
		else
			long_job = nil
		end
		long_job
	end
	
	def aqua_annotation_status(aqua_annotation = Aqua.annotations.keys)
		if Annotation.descendants.include?(aqua_annotation) then
			asa = aqua_annotation.get_vcf_annotation_status(self.id)
		else
			asa = aqua_annotation.map {|aqa| aqua_annotation_status(aqa)}
		end
		asa
	end
	
	def aqua_annotation_completed?(aqua_annotation = Aqua.annotations.keys)
		if aqua_annotation.is_a?(Array)
			aqua_annotation.all? {|aqa| aqa.vcf_annotation_completed?(self)}
		else
			aqua_annotation.vcf_annotation_completed?(self)
		end
	end
	
	def should_validate_content
		new_record? || updating_content || content_changed?
	end
	
	def sample_names
		snames = nil
		begin
			snames = YAML.load(read_attribute(:sample_names))
			if !snames.is_a?(FalseClass) then # this happens when an empty string was stored
				snames = [snames] unless snames.is_a?(Array)
			end
		rescue TypeError
			snames = read_attribute(:sample_names)
		end
		snames
	end
	
	# write the status of the object. This method also checks if the status to be set is valid.
	def sample_names= (value)
		if value.is_a?(Array)
			val = value.to_yaml
		else
			begin
				val = YAML.load(value).to_yaml
			rescue TypeError # this occurs if the string didnt have correct YAML format
				val = value.to_yaml
			end
		end
		write_attribute(:sample_names, val.to_s)
	end
	
	def get_sample_names()
		return get_sample_names_from_content if self.sample_names.nil?
		if self.sample_names.is_a?(String) then
			ret = YAML.load(self.sample_names)
			ret = [ret] unless ret.is_a?(Array)
		else
			ret = self.sample_names
		end
		ret.flatten
	end
	
	def self.get_sample_names_from_content(unzipped_content)
		ret = []
		StringIO.open(unzipped_content) do |io|
			io.each_line do |line|
				line.strip!
			#unzipped_content.split("\n").each do |line|
				next if line[0..1] == "##"
				if line[0] == "#" then
					ret = line.split("\t")[9..-1]
					break
				end
			end
		end
		# raise "the VCF does not contain recognisable sample names" if ret.size == 0
		(ret || []).flatten
	end
	
	def get_sample_names_from_content()
		VcfFile.get_sample_names_from_content(unzipped_content)
	end
	
	def self.get_filter_values_from_content(unzipped_content)
		ret         = Hash.new(0)
		ret["PASS"] = 0 # make PASS a default value
		StringIO.open(unzipped_content) do |io|
			io.each_line do |line|
				line.strip!
			#unzipped_content.split("\n").each do |line|
				next if line[0] == "#"
				# next if line[0..1] == "##"
				# break if line[0..3] == "#CHR"
				fvalues = line.strip.split("\t")[6].split(";")
				fvalues.each do |fvalue|
					ret[fvalue.force_encoding("UTF-8")] += 1
				end
			end
		end
		ret
	end
	
	def get_filter_values_from_content()
		VcfFile.get_filter_values_from_content(unzipped_content)
	end
	
	#  def users()
	#    self.institution.users.uniq
	#  end
	
	def self.all_without_data(ids = :all, opts = {})
		return [] if ids.nil?
		#attr = VcfFile.attribute_names.reject{|n| n == "content"}
		#opts[:select] = attr
		#ret = VcfFile.find(ids, opts).join(:aqua_status_annotations).includes(:aqua_status_annotations)
		ret = find_without_data(ids, opts)
		ret = [ret] unless ret.is_a?(Array)
		ret
	end
	
	def self.find_without_data(id, opts = {})
		attr          = VcfFile.attribute_names.reject {|n| n == "content"}
		opts[:select] = attr
		# VcfFile.joins(:aqua_status_annotations).includes(:aqua_status_annotations).find(id, opts)
		VcfFile.find(id, opts)
	end
	
	# Access to unzipped file content for easiert processing
	def unzipped_content()
		if @_unzipped.nil? then
			@_unzipped = Zlib::Inflate.inflate(self.content)
		end
		@_unzipped
	end
	
	def each_variation_call(&block)
		vcfp   = Vcf.new()
		ret    = []
		offset = 0
		StringIO.open(unzipped_content) do |io|
			io.each_line do |line|
				line.strip!
			# unzipped_content.split("\n").each do |line|
				if vcfp.parse_line(line)
					if self.respond_to?(:is_record_valid) then
						verdict = self.send(:is_record_valid, vcfp)
						if !verdict  then
							print("#{vcfp["chrom"]}:#{vcfp["pos"]} will be skipped-decision by #{self.class.name}\n".red)
							offset += (line.length + 1)
							next
						end
					end
					if block_given?
						yield vcfp, offset
					else
						ret << vcfp
					end
				end
				offset += (line.length + 1)
			end
		end
		return ret unless block_given?
		nil
	end
	
	# private
	def get_variation_calls(samplename, &block)
		all_sample_names = get_sample_names()
		if samplename.is_a?(String)
			smplidx = all_sample_names.index(samplename)
		else
			smplidx    = samplename
			samplename = all_sample_names[smplidx]
		end
		raise "#{samplename} not found in #{all_sample_names.join(",")}" if smplidx.nil?
		vcf_internal_sample_id = (smplidx + 1).to_s
		varcalls               = []
		self.each_variation_call do |vcfp, offset|
			# record = vcfp.to_record(false)
			record      = vcfp
			smpl_record = (record["samples"][samplename] || record["samples"][vcf_internal_sample_id])
			raise "sample name #{samplename} not found in VcfFile ##{self.id} at #{record.chrom}:#{record.pos}" if smpl_record.nil?
			
			if self.respond_to?(:is_record_valid) then
				verdict = self.send(:is_record_valid, record)
				next unless verdict
			end
			
			# chr = record["chr"]
			chr = record["chrom"]
			pos = record["pos"].to_i
			ref = record["ref"]
			gt  = smpl_record["GT"]
			## the alt field can have many alterations for different samples
			## the genotype contains the information at which alteration we have to look
			### altidx = gt.split(/[\/|]/)[1].to_i - 1
			### alt = record["alt"].split(",")[altidx]
			## now we have to set the genotype to 0/1 or 1/1 or 0|1 or 1|1 to code homozygous or heterozygous
			### gt1, sep, gt2 = gt.split("")
			#### gt2 = 1 if gt2.to_i > 1
			#### gt1 = 1 if gt1.to_i > 1
			#### gt = sprintf("%s%s%s", gt1,sep,gt2)
			start = pos
			
			## check if this record actually has a variation, otherwise discard this record
			next if record["alt"] == "."
			next if gt == "." or gt == "0/0" or gt == "./." or gt == "0|0" or gt == ".|." or gt == "0"
			
			gt     = "0/0" if gt == "0" or gt == "." # this should not happen, but lets make sure...
			filter = record["filter"]
			info   = record["info"]
			qual   = record["qual"]
			qual   = 0 if qual == "."
			
			gt = VcfFile.normalize_genotype(gt)
			
			## now we have to iterate over the alternative reads
			record["alt"].split(",").each_with_index do |alt, altidx|
				# gVCF
				next if alt.first == "<" and alt != "<CNV>"
				# next if alt == "<NON_REF>"
				
				# VCF 4.2 allows * as alternative allele - this should not be allowed here, because it just referes to 
				# and indel upstream of that variant in multi-sample VCFs
				# but in a multi-sample VCF this deletion should also be called as a seperate variant for that sample
				next if alt == "*"
				
				# in vcf 4.2 complex break points can be defined, but we dont deal with this.
				next if alt.index("[") or alt.index("]")
				
				# skip this alteration if the sample does not have it
				gt1, gt2 = smpl_record["GT"].split(/[\/|]/)
				if gt1 == gt2 then # we have a homozygous call
					next unless gt1.to_i == (altidx + 1)
				else # check if gt1 or gt2 is the same as altidx
					next unless gt1.to_i == (altidx + 1) or gt2.to_i == (altidx + 1) # this is for heterozygous calls
				end
				
				alttype = Alteration.determine_alttype(ref, alt)
				
				# to evaluate the GL field have a look at 
				# http://gatkforums.broadinstitute.org/discussion/1268/how-should-i-interpret-vcf-files-produced-by-the-gatk
				# http://samtools.github.io/hts-specs/VCFv4.2.pdf , p. 6, sec: GL
				gl = 100
				gq = smpl_record["GQ"]
				ps = (smpl_record["PS"] || nil)
				
				cn  = smpl_record["CN"] # copy number
				cnl = smpl_record["CNL"] # copy number liklihood
				
				fs = info["FS"].to_f # fisher strand bias
				
				if (!smpl_record["DP"].nil?) then
					dp = smpl_record["DP"].to_i
				else
					dp = 0 # a read depth of 0 should alarm the user.
				end
				
				if alttype == :snp or alttype == :indel
					stop = pos + ([ref.length, alt.length].max - 1)
				elsif alttype == :cnv
					stop = pos
					# taken from excavator2 output
					if !info["END"].nil? then
						stop = info["END"].to_i
					elsif info["SVLEN"] then
						stop = start + (info["SVLEN"].to_i - 1)
					end
					
					gq = 99 # fixed genotype quality for CNVs
					
					# We transform the CNF, which is the fraction of copy numbers
					# to the BAF (baf = alt/(alt+ref))
					# for that we fix ref=100000 and chose alt to be any number tha results in baf=cnv
					# this also means that alt_reads can be smaller than 0!
					# if !smpl_record["CNF"].nil? then
					# 	cnf = smpl_record["CNF"].to_f
					# 	ref_reads = 100000
					# 	alt_reads = ((cnf*ref_reads.to_f)/(1.0-cnf)).to_i
					# end
				elsif alttype == :sv # not supported yet...
					raise "Alttype SV not supported #{self.name}: #{chr}:#{pos}"
				else
					raise "Alttype not supported #{self.name}: #{chr}:#{pos}"
				end
				
				
				if not smpl_record["AD"].nil? then
					ad_fields = smpl_record["AD"].split(",")
					ref_reads = ad_fields.first
					alt_reads = (ad_fields[altidx + 1] || smpl_record["RD"].to_s.split(",")[altidx])
					ref_reads = -1 if ref_reads.nil?
					alt_reads = -1 if alt_reads.nil?
				elsif not smpl_record["AO"].nil? then
					ao_fields    = smpl_record["AO"].split(",")
					alt_read_sum = ao_fields.map(&:to_i).inject(:+)
					alt_reads    = ao_fields[altidx]
					ref_reads    = dp - (ao_fields - alt_reads)
				else
					# dont estimate number of ref/alt reads if they are not available.
					ref_reads = nil if ref_reads.nil?
					alt_reads = nil if alt_reads.nil?
				end
				
				varcall = {
					var:       {chr: chr, pos: pos, ref: ref, alt: alt, start: start, stop: stop},
					dp:        dp,
					filter:    filter,
					gl:        gl.to_f,
					gq:        gq.to_f,
					gt:        gt.to_s,
					ps:        ps.to_s,
					qual:      qual.to_f,
					ref_reads: ref_reads,
					alt_reads: alt_reads,
					cn:        cn,
					cnl:       cnl,
					fs:        fs,
					info:      info
				}
				if block_given? then
					yield varcall
				else
					varcalls << varcall
				end
			end
		end
		varcalls
	end
	
	def get_baf_histogram(smplname = nil, min_dp = 20)
		if smplname.nil? then
			ret = {}
			self.sample_names.each do |sname|
				ret[sname] = self.get_baf_histogram(sname, min_dp)
			end
			return ret
		end
		ret         = Hash[(0..100).map {|x| [x.to_f / 100.0, 0]}]
		ret.default = 0
		self.get_variation_calls(smplname) do |varcall|
			next if varcall[:gt] == "1/1" or varcall[:gt] == "1|1"
			next if varcall[:dp] < min_dp
			next unless varcall[:filter] == "PASS"
			baf = (varcall[:alt_reads].to_f / (varcall[:alt_reads].to_f + varcall[:ref_reads].to_f)).round(2)
			next if baf.nan?
			ret[baf] += 1
		end
		ret
	end
	
	def get_variants(include_offset = false, &block)
		variants = []
		self.each_variation_call do |vcfp, offset|
			records = parse_variant_record(vcfp)
			if include_offset
				records.each do |varhash|
					varhash[:offset] = offset
				end
			end
			if block_given? then
				records.each do |record|
					yield record
				end
			else
				variants += records
			end
		end
		if block_given? then
			nil
		else
			variants
		end
	end
	
	# creates a hash with the values from a Vcf object
	def parse_variant_record(vcfp)
		variants = []
		chr      = vcfp.chrom
		pos      = vcfp.pos.to_i
		ref      = vcfp.ref
		alt      = vcfp.alt
		start    = pos
		## check if this record actually has a variation, otherwise discard this record
		return [] if alt == "."
		# next if alt == "."
		## check if this record has multiple alternative alleles
		if alt.index(",") then
			alts = alt.split(",")
			alts.each do |altread|
				if altread != "<CNV>" then
					stop = pos + ([ref.length, altread.length].max - 1)
				else
					if !(vcfp["info"] || {})["END"].nil? then
						stop = vcfp["info"]["END"].to_i
					elsif !(vcfp["info"] || {})["SVLEN"].nil?
						stop = start + (vcfp["info"]["SVLEN"].to_i - 1)
					else
						raise "Cant determine CNV coordinates without SVLEN or END attributes"
					end
				end
				variants << {chr: chr, pos: pos, ref: ref, alt: altread, start: start, stop: stop}
			end
		else
			if alt != "<CNV>" then
				stop = pos + ([ref.length, alt.length].max - 1)
			else
				if !(vcfp["info"] || {})["END"].nil? then
					stop = vcfp["info"]["END"].to_i
				elsif !(vcfp["info"] || {})["SVLEN"].nil?
					stop = start + (vcfp["info"]["SVLEN"].to_i - 1)
				else
					raise "Cant determine CNV coordinates without SVLEN or END attributes"
				end
			end
			variants << {chr: chr, pos: pos, ref: ref, alt: alt, start: start, stop: stop}
		end
		variants
	end
	
	def get_variants_to_delete()
		vcfp     = Vcf.new()
		variants = []
		StringIO.open(unzipped_content) do |io|
			io.each_line do |line|
				line.strip!
			#unzipped_content.split("\n").each do |line|
				next if line =~ /^\W*$/
				if vcfp.parse_line(line)
					chr   = vcfp.chrom
					pos   = vcfp.pos.to_i
					ref   = vcfp.ref
					alt   = vcfp.alt
					start = pos
					## check if this record actually has a variation, otherwise discard this record
					next if alt == "."
					## check if this record has multiple alternative alleles
					if alt.index(",") then
						alts = alt.split(",")
						alts.each do |altread|
							if altread != "<CNV>" then
								stop = pos + ([ref.length, altread.length].max - 1)
							else
								if !(vcfp["info"] || {})["END"].nil? then
									stop = vcfp["info"]["END"].to_i
								elsif !(vcfp["info"] || {})["SVLEN"].nil?
									stop = start + (vcfp["info"]["SVLEN"].to_i - 1)
								else
									raise "Cant determine CNV coordinates without SVLEN or END attributes"
								end
							end
							variants << {chr: chr, pos: pos, ref: ref, alt: altread, start: start, stop: stop}
						end
					else
						if alt != "<CNV>" then
							stop = pos + ([ref.length, alt.length].max - 1)
						else
							if !(vcfp["info"] || {})["END"].nil? then
								stop = vcfp["info"]["END"].to_i
							elsif !(vcfp["info"] || {})["SVLEN"].nil?
								stop = start + (vcfp["info"]["SVLEN"].to_i - 1)
							else
								raise "Cant determine CNV coordinates without SVLEN or END attributes"
							end
						end
						variants << {chr: chr, pos: pos, ref: ref, alt: alt, start: start, stop: stop}
					end
				end
			end
		end
		return variants
	end
	
	## chunksize optimized
	def create_lookup(chunksize = 100, include_offset = false)
		variations = get_variants(include_offset)
		puts "[VcfFile(#{self.id})] create lookup for #{variations.size} variants..."
		lookup = {}
		offsetlookup = {}
		variations.each {|v|
			chr         = v[:chr]
			start       = v[:start]
			stop        = v[:stop]
			ref         = v[:ref]
			alt         = v[:alt]
			#key         = sprintf("%s:%d:%d:%s:%s", chr, start, stop, ref, alt)
			#key         = [chr, start, stop, ref, alt]
			key         = {chr: v[:chr], start: v[:start], stop: v[:stop],
			               ref: v[:ref], alt: v[:alt]}
			lookup[key] = nil
			if include_offset
				offsetlookup[key] = v[:offset]
			end
		}
		strt = Time.now
		puts "[VcfFile(#{self.id})] initilization at #{strt}..."
		
		# The alterations table is pretty static and not that large (some hundred thousands) 
		alt_map = {}
		Alteration.all.each do |a|
			alt_map[[a.ref, a.alt]] = a
			alt_map[a.id]           = a
		end
		
		variations.each_slice(chunksize) do |vars|
			# get region ids of variant
			reg_conditions = vars.map {|var|
				sprintf("(regions.name='%s' AND regions.start=%d AND regions.stop=%d AND coord_system = 'chromosome')", var[:chr], var[:start], var[:stop])
			}.join(" OR ")
			regions        = Region.where(reg_conditions)
			region_map     = {}
			regions.each do |r|
				region_map[[r.name, r.start, r.stop]] = r
				region_map[r.id]                      = r
			end
			
			# retrieve the Variation-object that belong to the given regions and alterations
			var_conditions = []
			vars.each do |var|
				reg = region_map[[var[:chr], var[:start], var[:stop]]]
				alt = alt_map[[var[:ref], var[:alt]]]
				if !reg.nil? and !alt.nil? then
					var_conditions << sprintf("(variations.region_id = %d AND variations.alteration_id = %d)", reg.id, alt.id)
				end
			end
			
			if var_conditions.size > 0 then
				existing_var_objs = Variation.where(var_conditions.join(" OR "))
			else
				existing_var_objs = [] # no variation objects exist of these region + alteratino combination...
			end
			# if Variation-objects exists for the given region and alteration then add it to the lookup
			existing_var_objs.each do |var|
				region      = region_map[var.region_id]
				alteration  = alt_map[var.alteration_id]
				key         = {chr: region.name, start: region.start, stop: region.stop,
				               ref: alteration.ref, alt: alteration.alt}
				lookup[key] = var
			end
		end
		if include_offset then
			lookup.keys.each do |k|
				newk = k.merge({offset: offsetlookup[k]})
				lookup[newk] = lookup.delete(k)
			end
		end
		puts "[VcfFile(#{self.id})] lookup for #{variations.size} variants created after #{Time.now - strt} sec"
		puts "[VcfFile(#{self.id})] lookup size: #{lookup.size} - DONE at #{Time.now}"
		variations = nil
		return lookup
	end
	
	def missing_variants(coords_only = true)
		return create_lookup.select {|k, v| v.nil?}.keys
	end
	
	def add_missing_variants()
		missing = missing_variants()
		d "[VcfFile(#{self.id})] adding #{missing.size} unknown variant object to database"
		ret = []
		return ret if missing.size == 0
		## add missing alterations
		missing_alterations = missing.map {|var| {ref: var[:ref], alt: var[:alt]}}.uniq
		Alteration.transaction do
			missing_alterations.each do |var|
				alteration = Alteration.find_or_create_by_ref_and_alt_and_alttype(var[:ref], var[:alt], Alteration.determine_alttype(var[:ref], var[:alt]))
				if !alteration.persisted?
					raise "Could not save alteration #{alteration} from #{var}" unless alteration.save
				end
			end
		end
		alterations = Hash[Alteration.all.map {|r| [[r.ref.upcase, r.alt.upcase], r]}]
		Region.transaction do
			missing.each do |var|
				region = Region.find_or_create_by_name_and_start_and_stop_and_coord_system(var[:chr], var[:start], var[:stop], "chromosome")
				if !region.persisted?
					raise "Could not save region #{region} from #{var}" unless region.save
				end
			end
		end
		variants         = []
		regions          = {}
		variation_buffer = []
		missing.each do |var|
			region = Region.find_by_name_and_start_and_stop_and_coord_system(var[:chr], var[:start], var[:stop], "chromosome")
			raise "Could not find region for #{var}" if region.nil?
			alter = alterations[[var[:ref].upcase, var[:alt].upcase]]
			v     = Variation.new(region_id: region.id, alteration_id: alter.id)
			# raise "Could not save variation #{v} from #{var}" unless v.save
			variation_buffer << v
			ret << v
			if variation_buffer.size >= 5000 then
				SnupyAgain::DatabaseUtils.mass_insert(variation_buffer, false)
				variation_buffer = []
			end
		end
		if variation_buffer.size > 0 then
			SnupyAgain::DatabaseUtils.mass_insert(variation_buffer, false)
		end
		## do a sanity check before leaving this procedure
		raise "Could not add all missing variants" if missing_variants.size > 0
		return ret
	end
	
	def self.import_variants(vcfid, user = nil)
		raise "Cannot import variants for unknown vcfid" if vcfid.nil?
		begin
			vcf_file = find(vcfid)
			print("Import variations for VCF ID ##{vcf_file.id} -> #{vcf_file.name}\n".red)
			Rails.logger.info("[LOG]Import variations for VCF ID ##{vcf_file.id} -> #{vcf_file.name}".red)
			vcf_file.update_attribute(:status, "ADDVARIANTS")
			# make sure all variants are present in the database
			puts "Adding missing variants for #{vcf_file}".blue
			missing_variants = vcf_file.add_missing_variants()
			# generate the variant index
			puts "Generating VCF File Index for #{vcf_file} / #{vcf_file.id}".blue
			vidx = VcfFileIndex.build_from_vcf_file(vcfid)
			if !vidx.save
				raise "VcfFileIndex could not be saved."
			end
			vcf_file.update_attribute(:status, "CREATED")
			# once this has been succesfull start the aqua_annotation for the vcf_file
			long_job = vcf_file.annotate(nil, user)
		rescue Exception => e
			find(vcfid).update_attribute(:status, "ERROR")
			raise e
		end
		true
	end
	
	# creates a Job that imports the missing variants in the background
	# This one first generates the variant index
	# and then start the annotation process for all available tools
	def import_variants(user)
		raise "VcfFile #{self} has not been saved, cannot import variants." if self.id.nil?
		long_job = LongJob.create_job({
			                               title:  "Import VCF #{self.name}",
			                               handle: self.class,
			                               method: :import_variants,
			                               user:   user,
			                               queue:  "annotation"
		                               }, false,
		                               self.id, user
		)
		long_job
	end
	
	def predict_tags_by_name()
		if self.tags.size == 0
			tag_name = "unknown"
			tag_name = "GATK" unless self.name.downcase.index("gatk").nil?
			tag_name = "GATK_RELAXED" unless self.name.downcase.index("gatk_relax").nil?
			tag_name = "GATK_RELAXED" unless self.name.downcase.index("gatk.relax").nil?
			tag_name = "MUTECT" unless self.name.downcase.index("mutect").nil?
			tag_name = "VarScan2" unless self.name.downcase.index("varscan").nil?
			tag_name = "VarScan2" unless self.name.downcase.index("var2denovo").nil?
			tag_name = "Platypus" unless self.name.downcase.index("ptp").nil?
			tag_name = "Platypus" unless self.name.downcase.index("platypus").nil?
			tag_name = "Excavator2" unless self.name.downcase.index("excavator").nil?
			if !tag_name.nil? then
				# check if tag is available
				tag = Tag.where(value: tag_name).where(object_type: "VcfFile").first
				if !tag.nil? then
					self.tags = [tag]
					self.save
				end
			end
		end
		self.tags
	end
	
	def self.create_vcf_file_from_upload(vcf_attributes, &block)
		vcfs    = []
		attrs   = {}
		content = (vcf_attributes["content"] || vcf_attributes[:content])
		
		# try to open the content as a zip file
		is_archive = true
		begin
			tmp = Zip::ZipFile.open(content.tempfile.path)
			tmp.close
		rescue Zip::ZipError
			is_archive = false
		end
		
		attrs[:name]           = vcf_attributes[:name]
		attrs[:contact]        = vcf_attributes[:contact]
		attrs[:type]           = vcf_attributes[:type]
		attrs[:institution_id] = vcf_attributes[:institution_id]
		attrs[:organism_id]    = vcf_attributes[:organism_id]
		attrs[:filename]       = content.original_filename #vcf_attributes[:filename]
		attrs[:md5checksum]    = vcf_attributes[:md5checksum]
		attrs[:tags]           = vcf_attributes[:tags]
		attrs[:status]         = :ADDVARIANTS
		# attrs[:status]         = :CREATED
		if !is_archive then
			content.tempfile.seek(0)
			fin     = File.new(content.tempfile.path, "rb")
			vcfdata = upload2vcfdata(fin.read)
			fin.close()
			if !block_given? then
				vcfs << create_vcf_file(attrs, vcfdata)
			else
				yield create_vcf_file(attrs, vcfdata)
			end
		else
			# check archive integrity
			given_md5 = (vcf_attributes[:md5checksum] || vcf_attributes["md5checksum"])
			if not (given_md5.to_s == "") then
				finb     = File.new(content.tempfile.path, "rb")
				checksum = calculate_checksum(finb.read)
				finb.close()
				if given_md5 != checksum then
					if !block_given? then
						return [{vcf_file: nil, alert: "Upload failed. MD5Checksum do no match.", created: false}]
					else
						yield ({vcf_file: nil, alert: "Upload failed. MD5Checksum do no match.", created: false})
					end
				end
			end
			# if we have an archive - let us look for a configuration file...
			config = get_config_from_upload(content.tempfile.path)
			if config.nil? then
				if !block_given? then
					return {vcf_file: nil, alert: "Config detected. Filename and format columns required in config.", created: false}
				else
					yield ({vcf_file: nil, alert: "Config detected. Filename and format columns required in config.", created: false})
				end
			end
			
			Zip::ZipFile.open(content.tempfile.path) do |zip_file|
				# Handle entries one by one
				zip_file.each do |entry|
					# Read into memory
					if entry.file? && entry.name.index(".vcf") then
						vcfdata = nil
						#begin 
						#	vcfdata = Zlib::GzipReader.new(entry.get_input_stream).read
						#rescue Zlib::GzipFile::Error => e
						#	vcfdata = entry.get_input_stream.read
						#end
						vcfdata = upload2vcfdata(entry.get_input_stream.read)
						
						myattrs = attrs.dup
						# the checksum only makes sense for the archive
						myattrs[:md5checksum] = nil
						#myattrs[:name] = myattrs[:name].to_s + "/#{File.basename(content.original_filename, ".zip")}/#{entry.name.gsub(/.gz$/, "").gsub(/.vcf$/, "")}"
						myattrs[:name]     = (myattrs[:name].to_s + "/#{entry.name.gsub(/.gz$/, "").gsub(/.vcf$/, "")}").gsub("//", "")
						myattrs[:filename] = myattrs[:filename].to_s + "/#{entry.name}"
						fileattrs          = config[entry.name]
						fileattrs.delete(:filename) # delete the filename....
						myattrs = myattrs.merge(fileattrs)
						myattrs.keys.each {|k|
							myattrs[k.to_sym] = (myattrs[k.to_sym] || myattrs[k.to_s])
						}
						if !block_given?
							vcfs << create_vcf_file(myattrs, vcfdata)
						else
							yield create_vcf_file(myattrs, vcfdata)
						end
						GC.start
						ObjectSpace.garbage_collect
					end
				end
			end
		end
		vcfs
	end
	
	# handles different types of data that is given in a .vcf file
	# if it is compressed the methods attempts to decompress it
	def self.upload2vcfdata(data)
		begin
			# first lets try to treat it as a blocked gzip file
			begin
				io     = StringIO.new(data)
				blocks = []
				r      = Bio::BGZF::Reader.new(io)
				while true do
					block = r.read_block
					blocks << block
					break unless block
				end
				return blocks.join('')
			rescue Bio::BGZF::NotBGZFError
				return Zlib::GzipReader.new(StringIO.new(data)).read
			end
				# return Zlib::Inflate.inflate(data)
				# rescue Zlib::DataError => e
		rescue Zlib::GzipFile::Error => e
			# data is not gzip compressed
			return data
		end
	end
	
	def self.get_config_from_upload(zipfile)
		allowed_fields = [:name, :contact, :type, :institution, :institution_id, :organism, :organism_id, :tool]
		config         = Hash.new({})
		Zip::ZipFile.open(zipfile) do |zip_file|
			zip_file.each do |entry|
				next unless entry.name == "config"
				header = nil
				entry.get_input_stream.each_line do |line|
					cols = line.strip.split("\t")
					next if line[0] == "#"
					if header.nil? then
						header = cols
						next
					else
						confrec        = Hash[cols.each_with_index.map {|v, i| [header[i].to_sym, v]}]
						confrec[:type] = (confrec[:format] || confrec["format"])
						filename       = (confrec[:filename] || confrec["filename"])
						if filename.to_s == "" || confrec[:type].to_s == ""
							config = nil
							break
						end
						confrec.select! {|k, v| allowed_fields.include?(k)}
						# set organism_id from organism name
						if !confrec[:organism].nil? then
							organism_id           = Organism.where(name: confrec[:organism]).pluck(:id).first
							confrec[:organism_id] = organism_id
							confrec.delete :organism
						end
						# set institution id from instituion name
						if !confrec[:institution].nil? then
							inst_id = Institution.where(name: confrec[:institution]).pluck(:id)
							inst_id = inst_id.first unless inst_id.nil?
							if inst_id.nil? then
								inst_id = Institution.where(id: confrec[:institution]).pluck(:id)
								inst_id = inst_id.first unless inst_id.nil?
							end
							confrec[:institution_id] = inst_id
							confrec.delete :institution
						end
						
						# get tool tags
						if !confrec[:tool].nil? then
							tags           = Tag.where(id: confrec[:tool].to_s.split(/[,;]/)).where(object_type: "VcfFile")
							tags           = Tag.where(value: confrec[:tool].to_s.split(/[,;]/)).where(object_type: "VcfFile") if tags.size == 0
							confrec[:tags] = tags
							confrec.delete(:tool)
						end
						
						
						config[filename] = confrec
					end
				end
			end
		end
		# d "###################"
		# pp config
		# d "###################"
		config
	end
	
	def sanity_check_content(content)
		header = []
		header_validated = false
		lineno = 0
		StringIO.open(content) do |io|
			io.each_line do |line|
				line.strip!
			#content.split("\n").each do |line|
				lineno += 1
				## check if all lines start with [#0-9XZ]
				raise "Invalid format for one line in the file (has to match /^[#0-9XZ]/)" if !line =~ /^[#0-9XYM]/
				# vcfp.parse_line(line)
				# instead of calling parse_line - which would be better, because we use this to parse VCF files
				# we perform the same checks as parse_line does, but we dont have to create the result structure
				# and thus safe parsing time...
				header << line if line[0, 2] == "##"
				next if line[0] == "#"
				if !header_validated then
					self.validate_vcf_header(header) if self.respond_to?(:validate_vcf_header)
					header_validated = true
				end
				cols = line.chomp.split("\t", -1)
				raise "VCF lines must have at least 8 fields (line: #{lineno})" if cols.size < 8
				raise "If FORMAT column is given sample columns are required  (line: #{lineno})" if cols.size == 9
				num_format_fields = cols[8].split(":").size
				num_sample_fields = cols[9..-1].map {|sc| sc.split(":").size}
				if num_sample_fields.any? {|nsf| nsf > num_format_fields}
					raise "Malformated sample(s) at line: #{lineno}. Sample fields dont match FORMAT fields (#{num_sample_fields.join(",")} vs. #{num_format_fields})."
				end
				self.validate_vcf_line(cols) if self.respond_to?(:validate_vcf_line)
				break if lineno >= 1000
			end
		end

		GC.start
		ObjectSpace.garbage_collect
	end
	
	# returns a Hash
	# {
	#   vcf_file: VcfFile object
	#   altert: alter message in case something went wrong
	#   created: boolean, true if a new VcfFile object was created. False if vcf_file is an already existing VcfFile object
	# }
	def self.create_vcf_file(attrs, content)
		rec = {}
		
		if content.size == 0 then
			return {vcf_file: nil,
			        alert:    "VcfFile does not contain any data.",
			        created:  false
			}
		end
		
		rec[:name]           = attrs[:name]
		rec[:contact]        = attrs[:contact]
		rec[:type]           = attrs[:type]
		rec[:institution_id] = attrs[:institution_id].to_i
		rec[:filename]       = attrs[:filename]
		if attrs[:organism_id].nil? or Organism.find_all_by_id(attrs[:organism_id]).size == 0 then
			return {vcf_file: nil,
			        alert:    "Organism not found. Please specify the organism explicitly for each VCF file.",
			        created:  false
			}
		else
			org               = Organism.find(attrs[:organism_id])
			rec[:organism_id] = org.id
		end
		rec[:status] = :CREATED
		
		tags = []
		if !attrs[:tags].nil? then
			if attrs[:tags].is_a?(Hash) then
				tags = Tag.find(attrs[:tags].values.flatten) unless attrs[:tags].values.flatten.size == 0 || attrs[:tags].values.flatten == [""]
			else
				tags = Tag.find(attrs[:tags])
			end
		end
		tags = [tags] if !tags.is_a?(Array)
		
		## check for existing name
		if not VcfFile.find_by_name(rec[:name]).nil? then
			vcf_file = VcfFile.find_by_name(rec[:name])
			return {vcf_file: vcf_file, notice: "Vcf name has to be unique.", created: false}
		end
		
		## check transfer
		content_checksum = calculate_checksum(content)
		if attrs[:md5checksum].to_s != "" then
			if content_checksum != attrs[:md5checksum] then
				return {vcf_file: nil, alert: "MD5Sum did not match. You said it is #{attrs[:md5checksum]} but we got #{content_checksum} from #{content.size} characters.", created: false}
			end
		end
		rec[:md5checksum] = content_checksum
		# check for existing VcfFile objects...
		existing_files = VcfFile.find_all_by_md5checksum(rec[:md5checksum], select: [:id, :md5checksum])
		if existing_files.size > 0 then
			return {vcf_file: VcfFile.find(existing_files.first.id),
			        notice:   "Vcf file already existed.",
			        created:  false}
		end
		
		## find sample names inside the vcf
		smplnames          = get_sample_names_from_content(content)
		rec[:sample_names] = smplnames
		if smplnames == 0 then
			return {vcf_file: nil, alert: "No samples found in this VCF(#{rec[:name]}). Line: #{line} ", created: false}
		end
		
		## find filter values inside the vcf
		filtervals    = get_filter_values_from_content(content)
		rec[:filters] = filtervals
		
		# compress content 
		rec[:content] = Zlib::Deflate.deflate(content, Zlib::BEST_COMPRESSION)
		
		# we need to initialize with the correct object that the 
		# uploaded file is supposed to be, so the validation can
		# access the correct validation methods.
		model = VcfFile
		if !(rec[:type] || rec["type"]).nil? then
			mytype         = (rec[:type] || rec["type"]).to_s.camelize
			allowed_models = ([VcfFile] + VcfFile.descendants).map(&:name)
			if !allowed_models.include?(mytype) then
				return {vcf_file: nil, alert: "Specified vcf type (#{mytype}) is not allowed. Choose one of [#{allowed_models.join(", ")}]", created: false}
			else
				model = Kernel.const_get(mytype)
			end
		end
		
		vcf_file                  = model.new(rec)
		vcf_file.updating_content = vcf_file.content.size > 0
		begin
			vcf_file.sanity_check_content(content)
		rescue Exception => e
			return {vcf_file: nil, alert: "VcfFile content did not pass sanity check. Reason: #{e.message}", created: false}
		end
		# initilize the aqua annotation status - we cant initizalize it because there is not ID at this moment
		# Still needs to be saved.
		# x             = vcf_file.aqua_annotation_status
		vcf_file.tags = tags
		return {vcf_file: vcf_file, notice: "OK", created: true}
	end
	
	def self.calculate_checksum(str)
		Digest::MD5.hexdigest(str)
	end
	
	# normalize the genotype field to be a combination of 1 and 0 even if there are more alternative reads in the VCF file
	# this happens when there are many samples in the VCF	
	def self.normalize_genotype(gt)
		gtref, gtalt = gt.split(/\/|/).map(&:to_i)
		delim        = gt.gsub(/[0-9]/, "")
		if gtref == gtalt && !(gtref == 0) then # homozygous call
			ret = "1#{delim}1"
		elsif gtref == gtalt and gtref == 0 then # homozygous call
			ret = "0#{delim}0"
		else
			if gtref == 0 or gtalt == 0 then # regular heterozygous read
				if gtref == 0 then
					ret = "0#{delim}1"
				else
					ret = "1#{delim}0"
				end
			else # heterozygous without reference
				if gtref < gtalt then
					ret = "1#{delim}2"
				else
					ret = "2#{delim}1"
				end
			end
		end
		ret
	end

end
