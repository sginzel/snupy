class VcfFileExcavator < VcfFile
	
	def self.supports
		[:cnv]
	end
	
	def validate_vcf_header(header)
		raise "VcfFile does not contain 'source=EXCAVATOR2v1.0' flag." if !header.any?{|line| !line.downcase.index("##source=excavator2v1.0").nil? }
	end
	
	def validate_vcf_line(columns)
		raise "Record does not contain a CNV" unless columns[4] == "<CNV>"
		raise "Record does not have SVNLEN" unless columns[7].index("SVLEN")
	end
	
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
				
				gl = 100
				gq = smpl_record["GQ"]
				ps = (smpl_record["PS"] || nil)
				
				cn  = smpl_record["CN"] # copy number
				cnl = smpl_record["CNL"] || smpl_record["FCP"] # copy number liklihood
				
				fs = info["FS"].to_f # fisher strand bias
				
				if (!smpl_record["DP"].nil?) then
					dp = smpl_record["DP"].to_i
				else
					dp = 0 # a read depth of 0 should alarm the user.
				end
				
				if alttype == :cnv
					stop = pos
					# taken from excavator2 output
					if !info["END"].nil? then
						stop = info["END"].to_i
					elsif info["SVLEN"] then
						stop = start + (info["SVLEN"].to_i - 1)
					end
					
					gq = 99 # fixed genotype quality for CNVs
					
				elsif alttype == :sv or alttype == :snp or alttype == :indel # not supported yet...
					raise "Alttype SV/SNP/INDEL not supported #{self.name}: #{chr}:#{pos}"
				else
					raise "Alttype not supported #{self.name}: #{chr}:#{pos}"
				end
				
				
				## Annotation resources
				# ftp://ftp.ensembl.org/pub/release-94/regulation/homo_sapiens/
				# ftp://ftp.ensembl.org/pub/release-94/gff3/homo_sapiens
				# ftp://ftp.ensembl.org/pub/grch37
				#
				# UCSC
				# http://hgdownload.soe.ucsc.edu/goldenPath/hg19/database/tableDescriptions.txt.gz
				# http://hgdownload.soe.ucsc.edu/goldenPath/hg19/database/ucscGenePfam.txt.gz
				# http://hgdownload.soe.ucsc.edu/goldenPath/hg19/database/pfamDesc.txt.gz
				# http://hgdownload.soe.ucsc.edu/goldenPath/hg19/database/wgRna.txt.gz # miRNA
				# https://genome-euro.ucsc.edu/cgi-bin/hgTrackUi?hgsid=230092017_6Uo9t9PQQAMkzApXlBbKtqiL3t8N&c=chr17&g=dgvPlus # known CNV
				# https://genome-euro.ucsc.edu/cgi-bin/hgTrackUi?hgsid=230092017_6Uo9t9PQQAMkzApXlBbKtqiL3t8N&c=chr17&g=wgEncodeTfBindingSuper # TF bindingsites
				#
				
				# we have no info about these values
				ref_reads = nil
				alt_reads = nil
				
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
	
	def predict_tags_by_name()
		if self.tags.size == 0
			tag = Tag.where(value: "Excavator2").where(object_type: "VcfFile").first
			if !tag.nil? then
				self.tags = [tag]
				self.save
			end
		end
		self.tags
	end

end