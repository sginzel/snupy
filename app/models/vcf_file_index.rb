#' VcfFileIndex
#' Structure of the index
#' Offset is the position of the line inside the uncompressed VcFile.content
# {chr: { pos => [ALT1, ALT2...]}}
# { alterations: {
#                  133321(alteration_id): ["A", "C"],
#                  123122: ["VERYLONGDELETEION", "C"], ...
#   },
#   "1" => {
#             12345: [[stop, variation_id, region_id, alteration_id, offset]]
#             32145: [[stop, variation_id, region_id, alteration_id, offset], [stop, variation_id, region_id, alteration_id, offset]]
#          },
#   "X" => {
#             789: [[stop, variation_id, region_id, alteration_id, offset]]
#             657: [[stop, variation_id, region_id, alteration_id, offset], [stop, variation_id, region_id, alteration_id, offset]]
#          }
# }
#'
#' varlist is an array of variation ids present in the VCF file.
#'
#' Both varlist and index are compressed using Zlib and by default are Marshalled objects.
#' If you expect to change ruby version you should use yaml instead.
#'
class VcfFileIndex < ActiveRecord::Base
	belongs_to :vcf_file
	attr_accessible :vcf_file_id, :compressed, :format, :varlist
	validates_uniqueness_of :vcf_file_id
	
	def index
		get_compressed_attribute(:index)
	end
	def index= (value)
		set_compressed_attribute(:index, value, 10.megabyte)
	end
	
	def varlist
		get_compressed_attribute(:varlist)
	end
	def varlist= (value)
		set_compressed_attribute(:varlist, value, 1.megabyte)
	end

	# returns the status of the object
	def get_compressed_attribute(attr_name)
		idx = read_attribute(attr_name)
		idx = Zlib::Inflate.inflate(idx) if self.compressed
		if (self.format.downcase == "yaml") then
			idx = YAML.load(idx)
		elsif (self.format.downcase == "bin")
			idx = Marshal.load(idx)
		else
			raise "Format #{self.format} is not supported by VcfFileIndex#index"
		end
		idx
	end
	
	# write the status of the object. This method also checks if the status to be set is valid.
	def set_compressed_attribute(attr_name, value, limit = nil)
		if (self.format.downcase == "yaml") then
			value = value.to_yaml
		elsif (self.format.downcase == "bin")
			value = Marshal.dump(value)
		else
			raise "Format #{self.format} is not supported by VcfFileIndex#index="
		end
		value = Zlib::Deflate.deflate(value) if self.compressed
		if !limit.nil? then
			if value.size > limit
				raise "Cannot store value #{attr_name} for VcfFileIndex#{self.id}. Entry too large (#{limit} allowed, #{value.size} given). Try compression or bin format."
			end
		end
		write_attribute(attr_name, value)
	end
	
	def generate_index(vcf_obj = nil)
		vcf_obj = VcfFile.find(self.vcf_file_id) if vcf_obj.nil?
		vcf_obj = VcfFile.find(vcf_obj) if vcf_obj.is_a?(Fixnum)
		if not %w(CREATED DONE ADDVARIANTS).include?(vcf_obj.status.to_s) then
			raise "Can not create index from unprocessed VcfFile (##{vcf_obj.id}) STATUS:#{vcf_obj.status} "
		end
		variation_ids = []
		idx = {alterations: {}}
		vcf_obj.create_lookup(100, true).each do |varhash, variation|
			if variation.nil? then
				raise "Not all variants have been added for #{vcf_obj.name}(##{vcf_obj.id}). Call add_missing_variants before generating an index."
			end
			chr = varhash[:chr]
			pos = varhash[:start]
			stop = varhash[:stop]
			ref = varhash[:ref]
			alt = varhash[:alt]
			offset = varhash[:offset]
			if (idx[:alterations][variation.alteration_id].nil?) then
				idx[:alterations][variation.alteration_id] = [ref, alt]
			end
			idx[chr] ||= {}
			idx[chr][pos] ||= []
			idx[chr][pos] << [stop, variation.id, variation.region_id, variation.alteration_id, offset]
			variation_ids << variation.id
		end
		self.varlist = variation_ids.sort.uniq
		self.index = idx
		true
	end
	
	def each(&block)
		records = []
		idx = self.index
		alterations = idx.delete(:alterations)
		idx.each do |chr, positions|
			positions.each do |start, positions|
				positions.each do |stop, varid, regid, altid, offset|
					ref, alt = alterations[altid]
					rec = {
						variation_id: varid, region_id: regid, alteration_id: altid,
					    chr: chr, pos: start, ref: ref, alt: alt, start: start, stop: stop,
						offset: offset
					}
					if (block_given?)
						yield rec
					else
						records << rec
					end
				end
			end
		end
		records
	end
	
	def coord_to_variant(&block)
		result = {}
		idx = self.index
		alterations = idx.delete(:alterations)
		idx.each do |chr, positions|
			positions.each do |start, positions|
				positions.each do |stop, varid, regid, altid, offset|
					ref, alt = alterations[altid]
					if (block_given?)
						yield({[chr, start, ref, alt] => varid})
					else
						result[[chr, start, ref, alt]] = varid
					end
				end
			end
		end
		result
	end
	
	def variation_to_line(&block)
		result = {}
		content = StringIO.new(self.vcf_file.unzipped_content)
		self.each do |record|
			varid = record[:variation_id]
			offset = record[:offset]
			content.seek(offset)
			line = content.readline
			if (block_given?)
				yield [varid, line]
			else
				result[varid] = line
			end
		end
		result
	end
	
	def to_a
		each()
	end
	
	def each_variant(&block)
		variations = Variation.where(id: self.varlist)
		return variations unless block_given?
		variations.each do |var|
			yield var
		end
	end
	
	def to_s
		"#<VcfFileIndex id: #{self.id || "nil"}, vcf_file_id: #{self.vcf_file_id}, compressed: #{self.compressed}, format: #{self.format}, index_size: #{(self.read_attribute(:index).size.to_f/1024).round(2)}KB, , varlist_size: #{(self.read_attribute(:varlist).size.to_f/1024).round(2)}KB >"
	end

	def self.generate(vcf_file, opts = {})
		build_from_vcf_file(vcf_file, opts)
	end

	def self.build_from_vcf_file(vcf_file, opts = {})
		# search & destroy existing
		vidx = VcfFileIndex.find_by_vcf_file_id(vcf_file)
		return vidx unless vidx.nil?
		vcf_file_id = (vcf_file.is_a?(VcfFile))?(vcf_file.id):(vcf_file)
		vidx = VcfFileIndex.new({
			vcf_file_id: vcf_file_id
		}.merge(opts))
		if vidx.vcf_file_id.nil?
			Rails.logger.error("Could not determine VCFFile ID for #{vcf_file} when building index".red)
			raise "Could not determine VCFFile ID for #{vcf_file} when building index".red
		end
		success = vidx.generate_index(vcf_file)
		return vidx if success
		nil
	end
	
	
	def self.refresh_indicies(ids = VcfFile.pluck(:id), force_new = true)
		ids = [ids] unless ids.is_a?(Array)
		applicable_ids = VcfFile.where(status: ["DONE", "CREATED", "ADDVARIANTS"])
			      .where(id: ids)
			      .pluck(:id)
		not_applicable_ids = ids - applicable_ids
		if (not_applicable_ids.size > 0) then
			puts "#{applicable_ids.size} VcfFile cannot be processed. Make sure they are 'DONE' or 'CREATED'".red
		end
		applicable_ids.each do |vcfid|
			vidx = VcfFileIndex.select([:id]).find_by_vcf_file_id(vcfid)
			if !vidx.nil? then
				if force_new then
					vidx.destroy unless vidx.nil?
				else
					puts "VCFFILE##{vcfid} already has an index".green
					next
				end
			end
			puts "[#{Time.now}]Building Index for VCFFILE##{vcfid}".yellow
			vidx = VcfFileIndex.build_from_vcf_file(vcfid)
			if vidx.nil?
				puts "Cant create index for VCFFILE##{vcfid}".red
			else
				vidx.save
			end
		end
	end
end
