# == Description
# The AquaAnnotationProcess implements the process to annotate a VcfFile. 
# == Example
#      # Setup Process for VcfFile
#      ap = AquaAnnotationProcess.new(VcfFile.first.id)
#      # start the process
#      success = ap.start()
#      puts "SUCCESS" if success
#  
class AquaAnnotationProcess
	
	# TODO: For windows machines the application tmp is selected.
	# @@TMPDIR = File.join("", "tmp")
	@@TMPDIR = Aqua.tempdir
	
	attr_accessor :vcfid, :tools
	
	def self.batch(vcf_file_ids, tools = nil)
		vcf_file_ids.each do |vcfid|
			ap = AquaAnnotationProcess.new(vcfid)
			success = ap.start(tools)
			if !success then
				puts "[AnnotationProcess] VcfFile (#{vcfid}) failed to annotate..."
				raise "AnnotationProcess failed for #{vcfid} - aborting."
			end
		end
	end
	
	# Create a new process for vcfid
	def initialize(vcfid)
		@vcfid = vcfid
		@tools = nil
	end
	
	# Run the Annotation-Process
	def start(tools = nil)
		vcf = VcfFile.find(@vcfid)
		success = true
		failed_tools = []
		failed_tool_messages = []
		exceptions = []
		
		if tools.nil? then
			@tools = Annotation.all_supporting_organism(vcf.organism.id)
		else
			@tools = [tools].flatten
		end
		@tools = [@tools] unless @tools.is_a?(Array)
		# load tools from name
		valid_tools = Annotation.all_supporting_organism(vcf.organism.id).map(&:name)
		@tools.select!{|t|
			if (t.is_a?(String))
				valid_tools.include?(t)
			elsif t.is_a?(Class)
				valid_tools.include?(t.name)
			else
				false
			end
		}
		@tools = @tools.map{|t|
			if (t.is_a?(String))
				Kernel.const_get(t.to_sym)
			elsif t.is_a?(Symbol)
				Kernel.const_get(t)
			else
				t
			end
		}
		# do not use annotation classes that are not part of the annotation chain...
		@tools.reject!{|t| t.type.to_s != "annotation"}

		# sort the tools by their requirements -> allows to have interdependencies between tools
		@tools = Annotation.sort_by_requirements(@tools)

		Annotation.log_info "***************************************************************************"
		Annotation.log_info "****************** AnnotationProcess for VcfFile #{@vcfid} ****************"
		Annotation.log_info "***************************************************************************"
		Annotation.log_info "	Configuration:"
		@tools.each do |t|
			Annotation.log_info "		[#{t.name}] #{t.configuration[:label]}"
			Annotation.log_info "			input  => #{t.configuration[:input]}"
			Annotation.log_info "			output  => #{t.configuration[:output]}"
			Annotation.log_info "			ready? => #{t.ready?}"
			Annotation.log_info "			satisfied? => #{t.satisfied?}"
			Annotation.log_info "			mutation_types => #{t.configuration[:supports].join(";")}"
		end
		Annotation.log_info "***************************************************************************"
		# select all tools that dont support the current data type and set their anontation status to complete.
		@tools.each{|t|
			if ((t.configuration[:supports] & vcf.class.supports).size == 0) then
				vcf.aqua_annotation_status(t).complete_annotation
			end
			# this is for modules that do not require an annotation class for some reason
			if (t.configuration[:supports].include?(:none)) then
				vcf.aqua_annotation_status(t).complete_annotation
			end
		}
		# select executable tools
		@tools.select!{|t| t.satisfied? && t.ready? }
		# remove all annotations which do not match the variation type it can annotate
		@tools.reject!{|t|
			(t.configuration[:supports] & vcf.class.supports).size == 0
		}
		@tools_processed = []
		@tools = Annotation.sort_by_requirements(@tools)

		Annotation.log_info "*********** START all #{@tools.size} satisfied, ready and able ****************"
		
		# The add_missing_variants should not depend on the applicable tools
		# This seems like a counter intuitive location to add missing variants, but its only here
		# where it actually matters. Because without proper annotation the VCFFile is not available to
		# extract samples from.
		# if (vcf.varindex.nil?) then
		# 	Annotation.log_info "	Creating varindex for (#{@vcfid})"
 		#	vcf.add_missing_variants() # add missing variants add variants which are not yet registered in the database
 		#	lookup = vcf.store_varindex() # TODO add varindex as feature
 		#	vcf.status = "ANNOTATIONPROCESS"
 		#	vcf.save!
		# end
		if (@tools.size > 0)
			# find all variants in VCF
			Annotation.log_info "	determine variants in the VcfFile (#{@vcfid})"
			# TODO Replace adding and create lookup with the usage of VcfFileIndex
			raise "#{vcf.id}/#{vcf.name} has no index. " if vcf.vcf_file_index.nil?
			#OLD vcf.add_missing_variants() # add missing variants add variants which are not yet registered in the database
			#OLD lookup = vcf.create_lookup() # TODO replace this with store_lookup
			#OLD vcf.status = "ANNOTATIONPROCESS"
			#OLD vcf.save!
			lookup = vcf.vcf_file_index
			vcf.update_attribute(:status, "ANNOTATIONPROCESS")
		end
		result = EventLog.record do |eventlog|
			missing_log = {}
			tool_timings = {}
			@tools.each do |t|
				Annotation.log_info "**************** Processing [#{t.name}] (#{t.configuration[:label]}) ******************"
				
				# skip tool if it is not ready yet.
				if !t.ready? then
					d "#{t.name} is not ready for annotation yet..."
					next
				end

				tool_successful = false
				# find out which kind of mutations the tool supports and the vcf provides
				mutation_types = t.configuration[:supports] & vcf.class.supports
				if (mutation_types.size == 0) # this shouldnt happen as we filter tools which cannot annotate
					raise "This tool mustn't be used with this VCF."
				end
				# find missing annotations
				Annotation.log_info "	determine variants to annotate..."
				missing = find_missing(t, vcf, lookup) # find missing finds variants which do not have an annotation for a tool yet
				miss_before_filter = missing.size
				missing = filter_mutation_type(missing, mutation_types)
				miss_after_filter = missing.size
				missing_log[t] = missing.size
				if missing.size > 0 then
					Annotation.log_info "	Processing #{missing.size} variants with #{t.configuration[:label] || "unknown tool"}"
					eventlog.add_message("#{Time.now} processing #{missing.size} variants with #{t.name} (#{t.configuration[:label]})")
					## check if required tools have been processed
					if !t.get_requirements.all?{|required_tool| @tools_processed.include?(required_tool)} then
						Annotation.log_warnings "#{t.name} cannot be processed because the requirements are not fulfilled".red
						exceptions << Exception.new("Consequtive Error for #{t.name} because of previously failed annotations")
						tool_successful = false
					else
						# process the VCF if all requirements have been met
						tmp_vcf_filepath = write_input_vcf(missing, vcf) if t.configuration[:input] == :vcf
						tmp_csv_filepath = write_input_csv(missing, vcf) if t.configuration[:input] == :csv

						# Process the VCF with the tool
						# Store potential exceptions and fail messages from the tools
						begin
							tool_timings[t.name] = Time.now.to_f
							annot_tool = t.new({})
							if t.configuration[:input] == :csv then
								tool_successful = annot_tool.annotate_and_store(tmp_csv_filepath, vcf)
							elsif t.configuration[:input] == :vcf
								tool_successful = annot_tool.annotate_and_store(tmp_vcf_filepath, vcf)
							elsif t.configuration[:input].nil?
								tool_successful = true
								Annotation.log "[#{t.name}] Annotion tool does not require input."
							else
								tool_successful = false
								raise "[#{t.name}] #{t.configuration[:input]} is not a supported input format"
							end

							if !tool_successful.is_a?(TrueClass) then
								Annotation.log "[#{t.name}] NOT SUCESSFULL"
								failed_tool_messages << tool_successful unless tool_successful.is_a?(FalseClass)
								tool_successful = false
							end
						rescue RuntimeError => e
							tool_successful = false
							exceptions << e
						ensure
							tool_timings[t.name] = (Time.now.to_f - tool_timings[t.name]).round(3)
						end
					end
					if tool_successful then
						vcf.aqua_annotation_status(t).complete_annotation
					else
						failed_tools << t
						vcf.aqua_annotation_status(t).failed_annotation
					end
					success = success && tool_successful
				else
					if (miss_before_filter > 0) then
						Annotation.log_info "	This tool cannot annotate any variants which are present in #{t.configuration[:label] || "unknown tool"}"
					else
						Annotation.log_info "	There are no variants to annotate with #{t.configuration[:label] || "unknown tool"}"
					end
					vcf.aqua_annotation_status(t).complete_annotation
					success = success && true
				end
				@tools_processed << t if tool_successful
			end
			if !success then
				vcf.status = "ERROR"
				vcf.save!
				Annotation.log_error "      [ERROR]: #{failed_tools.size} Tools failed: #{failed_tools.map{|t| t.name}.join(", ")}"
				if failed_tool_messages.size > 0 then
					failed_tool_messages.each do |m|
						d "          -> [ERROR-Message]: #{m}"
					end
				end
				vcf.save!
				error_message = "AnnotationProcess failed. Errornous annotations: #{failed_tools.map{|t| t.name}.join(", ")}"
				error_message << "\n ERRORS: \n" + failed_tool_messages.join("\n--------\n") if failed_tool_messages.size > 0
				if exceptions.size > 0 then
					error_message << "\n EXCEPTIONS: \n"
					exceptions.each do |exep|
						error_message << exep.message + "\n"
						error_message << exep.backtrace.join("\n=>") + "\n"
						error_message << " #### ERROR MESSAGE OF NEXT TOOL #####\n"
					end
				end
				Annotation.log_error(error_message)
				raise Exception.new(error_message)
			else
				if vcf.aqua_annotation_completed? then
					vcf.status = "DONE"
				else
					vcf.status = "INCOMPLETE"
				end
				vcf.save!
			end
			eventlog.data = {
					tools: @tools.map(&:name),
					vars_missing_annotation: missing_log,
					timings: tool_timings,
					num_tools: @tools.size,
					failed_tools: failed_tools.map{|t| t.name},
					num_failed: failed_tools.size,
					success: success,
			}
			success
		end
		Annotation.log_info "*********************** DONE for VcfFile #{@vcfid} ********************"
		
		return result
		
	end
	
	# Find variants in the VcfFile that were not yet annotated with the given set of tools. 
	# Returns a sorted hash as returned by VcfFile.create_lookup. Format is
	#       { 
	#         {chr: 1,  start: 2, stop: 2, ref: "A", alt: "G"} => #<Variation id: 3397842, region_id: 3248204, alteration_id: 20707...>,
	#         {chr: 11, start: 4, stop: 4, ref: "G", alt: "T"} => #<Variation id: 3397843, region_id: 3248205, alteration_id: 20703...>,
	#         {chr: X,  start: 3, stop: 4, ref: "A", alt: "GA"} => #<Variation id: 3397844, region_id: 3248206, alteration_id: 20704...>,
	#       } 
	# If any one tool annotated a Variation before the variant is marked as previously processed, even if 
	# another tools might not have annotated the given variant. This can happen when a new Annotation-tool
	# is integrated. Please use the appropriate rake tasks to add or remove annotation tools from an existing installation. 
	def find_missing(tools, vcf, vcf_variant_lookup)
		return find_missing_from_index(tools, vcf, vcf_variant_lookup) if vcf_variant_lookup.is_a?(VcfFileIndex)
		tools = [tools] unless tools.is_a?(Array)
		# check each variation and if it was annotated with any of the selected tools
		
		missing = {}
		varid2coord = {}
		vcf_variant_lookup.each do |coord, var|
			raise "vcf_variant_lookup must not contain unknown variants" if var.nil? or !var.is_a?(Variation)
			missing[coord] = var
			varid2coord[var.id] = coord
		end
		tools.each do |t|
			if (missing.size > 0) then
				varids = missing.values.flatten.map(&:id).uniq
				varids.each_slice(100) do |varids_slice|
					annot_by_tool = t.find_annotated(varids_slice, vcf.organism.id).uniq
					annot_by_tool.each do |varid|
						raise "Variation not in lookup" if varid2coord[varid].nil?
						missing.delete(varid2coord[varid])
					end
				end
			end
		end
		
		# sort missing - for many Gb of missing variations this might be not efficient
		# Sorting is required so the missing variants can be written to a sorted file
		coords = sort_coords(missing.keys)
		
		ret = {}
		coords.each do |coord|
			ret[coord] = missing[coord]
		end
		
		return ret
	end
	
	def sort_coords(coords)
		chr_order = Hash[((1..22).to_a + ["X", "Y", "M"]).each_with_index.map{|x, idx| [x.to_s, idx]}]
		chr_order.default = 1000000000
		coords.sort{|c1, c2|
			chr1 = c1[:chr]
			chr2 = c2[:chr]
			pos1 = c1[:start].to_i
			pos2 = c2[:start].to_i
			alt1 = c1[:alt]
			alt2 = c2[:alt]
			ret = 0
			if (chr1 != chr2)
				chr_order[chr1.to_s] <=> chr_order[chr2.to_s]
				#if (chr1.to_i == 0 and chr2.to_i == 0) # both chromsome is a character
				#	chr1 <=> chr2
				#elsif (chr1.to_i == 0 or chr2.to_i == 0) # one chromsome is a character
				#	ret =  1 if chr1.to_i == 0
				#	ret = -1 if chr2.to_i == 0
				#else                                     # no character as chromosome
				#	ret = c1[:chr].to_i <=> c2[:chr].to_i
				#end
			else # chromsome is same not go for position
				if (pos1 != pos2) then
					ret = pos1 <=> pos2
				else
					ret = alt1 <=> alt2
				end
			end
			ret
		}
		
	end
	
	def find_missing_from_index(tools, vcf, vcf_file_index)
		missing = {}#Hash[vcf_file_index.varlist.map{|vid| [vid, vid]}]
		varids = vcf_file_index.varlist
		vcf_file_index.each do |coords|
			missing[coords[:variation_id]] = coords
		end
		tools = [tools] unless tools.is_a?(Array)
		tools.each do |t|
			if (missing.size > 0) then
				varids = missing.keys
				varids.each_slice(100) do |varids_slice|
					annot_by_tool = t.find_annotated(varids_slice, vcf.organism.id).uniq
					annot_by_tool.each do |varid|
						missing.delete(varid)
					end
				end
			end
		end
		coords = missing.values.flatten
		coords = sort_coords(coords)
		
		return Hash[coords.map{|x| [x, x[:variation_id]]}]
	
	end
	
	# Filters the output of find_missing to the mutation_types which are supported by each tool
	# input: 
	# {:chr=>"7", :start=>56296553, :stop=>56296553, :ref=>"G", :alt=>"T"} => #<Variation id: 8, region_id: 8, alteration_id: 4, created_at: "2015-10-27 15:53:58", updated_at: "2015-10-27 15:53:58">
	def filter_mutation_type(missing, mutation_types)
		allowedtypes = Hash[mutation_types.map{|mt| [mt.to_sym, true]} + mutation_types.map{|mt| [mt.to_s, true]}]
		allowedtypes.default = false
		missing.keys.each do |coords|
			alttype = Alteration.determine_alttype(coords[:ref], coords[:alt])
			if (!allowedtypes[alttype]) then
				missing.delete(coords)
			end
		end
		missing
	end
	
	# Write a set of missing variants to a new temporary file in VCF format. 
	# Filename is composed of @@TMPDIR and the current timestamp (based on seconds).
	# The VCF is formated as follows:
	#     ##fileformat=VCFv4.1
	#     ##AquaAnnotationProcess='version=1.0;vcf=121;species=homo sapiens;date=2014-12-01 13:19:39 +0100;numvar=2'
	#     ##INFO=<ID=VID,Number=1,Type=Integer,Description="Snupy variation_id"
	#     #CHROM  POS     ID      REF     ALT     QUAL    FILTER  INFO    FORMAT  SMPL
	#     1       1       .       G       T       100     PASS    VID=3397829   .       .
	#     1       2       .       G       A       100     PASS    VID=3397830   .       .
	# The VID attribute should be used to connect a variant in the VCF to the correct Variation.
	# The AquaAnnotationProcess VCF tag holds information about the VcfFile that was annotated.
	def write_input_vcf(missing, vcf, fname = nil)
		if (fname.nil?) then
			fname = File.join(@@TMPDIR, vcf.id.to_s + "_" + Time.now.to_s.gsub(/[ :+]/, "-") + ".vcf")
		end
		cnt = 1
		orgfname = fname
		while (File.exists?(fname)) do
			#fname = File.join(@@TMPDIR, vcf.id.to_s + "_" + Time.now.to_s.gsub(/[ :+]/, "-") + "_#{cnt.to_s.rjust(4,"0")}.vcf")
			cntr = cnt.to_s.rjust(4,"0")
			fname = File.join( File.dirname(orgfname), "#{File.basename(orgfname, ".vcf")}_#{cntr}.vcf")
			cnt += 1
		end
		fout = File.new(fname, "w+")
		# write header
		fout.write("##fileformat=VCFv4.1
##AquaAnnotationProcess='version=1.0;vcf=#{vcf.id};species=#{vcf.organism.name};date=#{Time.now.to_s};numvar=#{missing.size}'
##INFO=<ID=VID,Number=1,Type=Integer,Description=\"Snupy variation_id\">
##INFO=<ID=IMPRECISE,Number=0,Type=Flag,Description=\"Imprecise structural variation\">
##INFO=<ID=SVTYPE,Number=1,Type=String,Description=\"Type of structural variant\">
##INFO=<ID=SVLEN,Number=.,Type=Integer,Description=\"Difference in length between REF and ALT alleles\">
##INFO=<ID=END,Number=1,Type=Integer,Description=\"End position of the variant described in this record\">
#CHROM	POS	ID	REF	ALT	QUAL	FILTER	INFO	FORMAT	SMPL
")
		missing.each do |coords, var|
			if (var.is_a?(Variation))
				vid = var.id
			else
				vid = var
			end
			if (coords[:alt] != "<CNV>") then
				fout.write(%W(#{coords[:chr]} #{coords[:start]} #{vid} #{coords[:ref]} #{coords[:alt]} 100 PASS VID=#{vid} . .).join("\t").strip)
			else
				raise "Invalid coords #{coords.to_json}" if coords[:stop].nil? or coords[:start].nil?
				fout.write(%W(#{coords[:chr]} #{coords[:start]} #{vid} #{coords[:ref]} #{coords[:alt]} 100 PASS VID=#{vid};IMPRECISE;SVTYPE=CNV;END=#{coords[:stop]};SVLEN=#{(coords[:stop] - coords[:start]) + 1} . .).join("\t").strip)
			end
			fout.write("\n")
		end
		fout.close()
		File.chmod(0440, fout.path) # make the file read only to prevent modifications
		fout.path
	end
	
	# Write a set of missing variants to a new temporary file in CSV format. 
	# Filename is composed of @@TMPDIR and the current timestamp (based on seconds).
	# The CSV is formated as follows:
	#     #AquaAnnotationProcess='version=1.0;vcf=121;species=homo sapiens;date=2014-12-01 13:19:39 +0100;numvar=2'
	#     chr	start	stop	ref	alt	variation_id
	#     1  	1    	1   	G  	T  	3397829
	#     1  	2    	3   	G  	AA 	3397830
	# The variation_id attribute should be used to connect a variant in the VCF to the correct Variation.
	def write_input_csv(missing, vcf)
		fout = File.new(File.join(@@TMPDIR, vcf.id.to_s + "_" + Time.now.to_s.gsub(/[ :+]/, "-") + ".csv"), "w+")
		# write header
		fout.write("##AquaAnnotationProcess='version=1.0;vcf=#{vcf.id};species=#{vcf.organism.name};date=#{Time.now.to_s};numvar=#{missing.size}'
##chr	start	stop	ref	alt	variation_id
")
		#missing.each do |coords, var|
		missing.each do |coords, var|
			if (var.is_a?(Variation))
				vid = var.id
			else
				vid = var.to_i
			end
			fout.write(%W(#{coords[:chr]} #{coords[:start]} #{coords[:stop]} #{coords[:ref]} #{coords[:alt]} #{vid}).join("\t").strip)
			fout.write("\n")
		end
		fout.close()
		File.chmod(0440, fout.path)
		fout.path
	end
	
	def self.vcf_to_vcf(vcf_path, vcf)
		fin = File.new(vcf_path, "r")
		fname = File.join(@@TMPDIR, vcf.id.to_s + "_" + Time.now.to_s.gsub(/[ :+]/, "-") + ".vcf")
		cnt = 1
		while (File.exists?(fname)) do 
			fname = File.join(@@TMPDIR, vcf.id.to_s + "_" + Time.now.to_s.gsub(/[ :+]/, "-") + "_#{cnt.to_s.rjust(4,"0")}.vcf")
		end
		fout = File.new(fname, "w+")
		fout.write("##fileformat=VCFv4.1
##AquaAnnotationProcess='version=1.0;vcf=#{vcf.id};species=#{vcf.organism.name};date=#{Time.now.to_s};numvar=?'
##INFO=<ID=VID,Number=1,Type=Integer,Description=\"Snupy variation_id\">
#CHROM	POS	ID	REF	ALT	QUAL	FILTER	INFO	FORMAT	SMPL
")
		fin.each_line do |line|
			chr, start, id, ref, alt, rest = line.strip.split("\t", 6)
			# Indels are coded differently from what the VCF standard says
			if alt[0] == "+" then # insertion
				alt = alt.gsub(/^\+/, ref)
			elsif alt[0] == "-" #deletion
				alt = alt.gsub(/^\-/, ref)
				ref, alt = alt, ref
			end
			fout.write(%W(#{chr} #{start} . #{ref} #{alt} 100 PASS VID= . .).join("\t").strip)
			fout.write("\n")
		end
		fout.close()
		File.chmod(0440, fout.path) # make the file read only to prevent modifications
		fout.path
	end

	def self.vcf_to_csv(vcf_path, vcf)
		fin = File.new(vcf_path, "r")
		fname = File.join(@@TMPDIR, vcf.id.to_s + "_" + Time.now.to_s.gsub(/[ :+]/, "-") + ".csv")
		cnt = 1
		while (File.exists?(fname)) do 
			fname = File.join(@@TMPDIR, vcf.id.to_s + "_" + Time.now.to_s.gsub(/[ :+]/, "-") + "_#{cnt.to_s.rjust(4,"0")}.csv")
		end
		fout = File.new(fname, "w+")
		fout.write("##AquaAnnotationProcess='version=1.0;vcf=#{vcf.id};species=#{vcf.organism.name};date=#{Time.now.to_s};numvar=?'
##chr	start	stop	ref	alt	variation_id
")
		fin.each_line do |line|
			chr, start, id, ref, alt, rest = line.strip.split("\t", 6)
			# Indels are coded differently from what the VCF standard says
			if alt[0] == "+" then # insertion
				alt = alt.gsub(/^\+/, ref)
			elsif alt[0] == "-" #deletion
				alt = alt.gsub(/^\-/, ref)
				ref, alt = alt, ref
			end
			next if (alt == "<CNV>")
			stop = start.to_i + ("#{ref}#{alt}".gsub("-", "").size - 2)
			fout.write(%W(#{chr} #{start} #{stop} #{ref} #{alt} #{"UNKNOWN_VARID"}).join("\t").strip)
			fout.write("\n")
		end
		fout.close()
		File.chmod(0440, fout.path) # make the file read only to prevent modifications
		fout.path
	end

end
