class VcfFileVarscan < VcfFile
	
	def self.supports
		[:snp, :indel]
	end
	
	def validate_vcf_header(header)
		raise "VcfFile does not contain VarScan source flag (source=varscan)." if !header.any?{|line| !line.downcase.index("##source=varscan").nil? }
	end
	
	def validate_vcf_line(columns)
		raise "Not enough columns to be a VarScan file. Somatic require 11 and trio require 12 columns." unless columns.size == 11 or columns.size == 12
	end
	
	def get_variation_calls(samplename, &block)
		vcfp = Vcf.new()
		varcalls = []
		## determine sample_id in VCF (the VCF library doesn always have the correct sample names from the header but rather uses numbers)
		all_sample_names = self.sample_names
		raise "Not a VarScanFile" if all_sample_names.size != 2 and all_sample_names.size != 3
		vcf_internal_sample_id = (all_sample_names.index(samplename) + 1).to_s
		sample_type = "UNKNOWN"
		if %w(NORMAL TUMOR MOTHER FATHER CHILD).include?(samplename.upcase)
			sample_type = "SOMATIC" if samplename == "TUMOR"
			sample_type = "GERMLINE" if samplename == "NORMAL"
			sample_type = "DENOVO" if samplename == "CHILD"
			sample_type = "PARENT" if samplename == "MOTHER"
			sample_type = "PARENT" if samplename == "FATHER"
		else
			raise "Cant parse de novo records when the samples are not named CHILD/MOTHER/FATHER" if all_sample_names.size > 2
			sample_type = "SOMATIC" if all_sample_names.index(samplename) == 1
			sample_type = "GERMLINE" if all_sample_names.index(samplename) == 0
		end
		unzipped_content.split("\n").each do |line|
			if vcfp.parse_line(line)
				record = vcfp
				smpl_record = (record["samples"][samplename] || record["samples"][vcf_internal_sample_id])
				raise "sample name #{samplename} not found in VcfFile ##{self.id}" if smpl_record.nil?
				
				chr = record["chrom"]
				pos = record["pos"].to_i
				ref = record["ref"]
				gt = smpl_record["GT"]
				gt = "0/0" if gt == "0" or gt == "."
				gt = self.class.normalize_genotype(gt)
				next if gt == "." or gt == "0/0" or gt == "./." or gt == "0|0" or gt == ".|." or gt == "0"
				## a varscan file might have more than one alternative allele, if the variation is heterozygous without a reference allele
				## this case i not formated in the way that is specified in the VCF format description, so we need to cope with it as a special case
				alts = record["alt"]
				alts.split(/[\/|]/).each do |alt|
					# gVCF
					next if alt.first == "<"
					gt = "1/2" if alts.size > 1 and (gt == "0/1" or gt == "1/0")
					start = pos
					stop = pos + ([ref.length, alt.length].max - 1)
					
					## check if this record actually has a variation, otherwise discard this record
					next if alt == "."
					next if gt == "." or gt == "0/0" or gt == "./." or gt == "0|0" or gt == ".|."
					
					# Indels are coded differently from what the VCF standard says
					if alt[0] == "+" then # insertion
						alt = alt.gsub(/^\+/, ref)
					elsif alt[0] == "-" #deletion
						alt = alt.gsub(/^\-/, ref)
						ref, alt = alt, ref
					end
					
					dp = smpl_record["DP"]
					filter = record["filter"]
					info = record["info"]
					gl = 100
					gq = smpl_record["GQ"]
					ps = (smpl_record["PS"] || "NA")
					
					## let us skip processing of the record if it was not classfied as SOMATIC or GERMLINE
					if sample_type == "SOMATIC"
						next unless info["SS"].to_s == "2"
					elsif sample_type == "GERMLINE"
						next unless info["SS"].to_s == "1"
					elsif sample_type == "DENOVO"
						next unless info["STATUS"].to_s == "3"
					elsif sample_type == "PARENT"
						if info["STATUS"].to_s == "3" then
							raise "Something went wrong. I got a De-Novo call from a Mother or Father for this record: #{line.to_s}"
						end
					end
					
					## FIXME VARScan is not using the same AD field that GATK is using
					## FIXME VarScan 2.2.11 uses two field called AD and RD to carry alternative depth and reference depth
					## FIXME This might be handled differently in VarScan 3.5.
					if (!smpl_record["RD"].nil?) then
						if gt == "0|1" or gt == "1|0" or gt == "0/1" or gt == "1/0" or gt == "1|1" or gt == "1/1" then # for regular heterozygous and homozyogous call this is easy
							ref_reads = (smpl_record["RD"] || "-1")
							alt_reads = (smpl_record["AD"] || "-1")
						else # heterozygous without reference needs more attention as there is no reference read at that position
							ref_reads = 0 
							altidx = alts.split(/[\/|]/).index(alt)
							alt_reads = (smpl_record["AD"].split(",")[altidx] || "-1")
						end 
					else
						ref_reads = (smpl_record["AD"] || "-1,-1").split(",")[0]
						alt_reads = (smpl_record["AD"] || "-1,-1").split(",")[1]
					end   
					
					qual = record["qual"]
					if qual.to_i == 0 then
						## set the quality value to a decent value so it is not always filtered
						## This is only done because we trust the VarScan files to be good files
						qual = 100 
					end
					
					varcall = {
												var:{chr: chr, pos: pos, ref: ref, alt: alt, start: start, stop: stop},
												dp: dp.to_f,
												filter: filter,
												gl: gl.to_f,
												gq: gq.to_f,
												gt: gt.to_s,
												ps: ps.to_s,
												qual: qual.to_f,
												ref_reads: ref_reads,
												alt_reads: alt_reads, 
												info: info
											}
					if block_given? then
						yield varcall
					else
						varcalls << varcall
					end
				end
			end
		end
		return nil if block_given?
		return varcalls
	end
	
	#def get_variants(include_offset)
	#
	#end
	
	# creates a hash with the values from a Vcf object
	def parse_variant_record(vcfp)
		result = []
		# record = vcfp.to_record(false)
		record = vcfp
		chr = record["chrom"]
		pos = record["pos"].to_i
		ref = record["ref"]
		alts = record["alt"]
		start = pos
		
		return [] if alts == "."
		alts.split("/").each do |alt|
			## check if this record actually has a variation, otherwise discard this record
			next if alt == "."
			## check if this record has multiple alternative alleles
			if alt.index(",") then
				alt.split(",").each do |altread|
					stop = pos + ([ref.length, altread.length].max - 1)
					result << {chr: chr, pos: pos, ref: ref, alt: altread, start: start, stop: stop}
				end
			else
				stop = pos + ([ref.length, alt.length].max - 1)
				result << {chr: chr, pos: pos, ref: ref, alt: alt, start: start, stop: stop}
			end
		end
		result
	end
	
	def get_variants_to_delete()
		### write to temp file
		vcfp = Vcf.new()
		variants = []
		unzipped_content.split("\n").each do |line|
			if vcfp.parse_line(line)
				# record = vcfp.to_record(false)
				record = vcfp
				chr = record["chrom"]
				pos = record["pos"].to_i
				ref = record["ref"]
				alts = record["alt"]
				start = pos

				alts.split("/").each do |alt|
					## check if this record actually has a variation, otherwise discard this record
					next if alt == "."
					## check if this record has multiple alternative alleles
					if alt.index(",") then
						alt.split(",").each do |altread|
							stop = pos + ([ref.length, altread.length].max - 1)
							variants << {chr: chr, pos: pos, ref: ref, alt: altread, start: start, stop: stop}
						end
					else
						stop = pos + ([ref.length, alt.length].max - 1)
						variants << {chr: chr, pos: pos, ref: ref, alt: alt, start: start, stop: stop}
					end
				end
			end
		end
		
		return variants		
	end
	
	def predict_tags_by_name()
		if self.tags.size == 0
			tag = Tag.where(value: "VarScan2").where(object_type: "VcfFile").first
			if !tag.nil? then
				self.tags = [tag]
				self.save
			end
		end
		self.tags
	end
	
end