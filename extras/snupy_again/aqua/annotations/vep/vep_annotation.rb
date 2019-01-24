# == Description
# Performs an annotation using Variant Effect Predictor by Ensembl.

class VepAnnotation < Annotation
	
	# register tool is on bottom of class declaration.
	
	@@VEPCONFIG = nil
	@@CONFIGCACHE = {}
	
	@@SEVERITY = {
		"transcript_ablation"	 => 	1, 
		"splice_acceptor_variant"	 => 	2, 
		"splice_donor_variant"	 => 	3, 
		"stop_gained"	 => 	4, 
		"frameshift_variant"	 => 	5, 
		"stop_lost"	 => 	6, 
		"start_lost"	 => 	7, 
		"transcript_amplification"	 => 	8, 
		"inframe_insertion"	 => 	9, 
		"inframe_deletion"	 => 	10, 
		"missense_variant"	 => 	11, 
		"protein_altering_variant"	 => 	12, 
		"splice_region_variant"	 => 	13, 
		"incomplete_terminal_codon_variant"	 => 	14, 
		"stop_retained_variant"	 => 	15, 
		"synonymous_variant"	 => 	16, 
		"coding_sequence_variant"	 => 	17, 
		"mature_miRNA_variant"	 => 	18, 
		"5_prime_UTR_variant"	 => 	19, 
		"3_prime_UTR_variant"	 => 	20, 
		"non_coding_transcript_exon_variant"	 => 	21, 
		"intron_variant"	 => 	22, 
		"NMD_transcript_variant"	 => 	23, 
		"non_coding_transcript_variant"	 => 	24, 
		"upstream_gene_variant"	 => 	25, 
		"downstream_gene_variant"	 => 	26, 
		"TFBS_ablation"	 => 	27, 
		"TFBS_amplification"	 => 	28, 
		"TF_binding_site_variant"	 => 	29, 
		"regulatory_region_ablation"	 => 	30, 
		"regulatory_region_amplification"	 => 	31, 
		"feature_elongation"	 => 	32, 
		"regulatory_region_variant"	 => 	33, 
		"feature_truncation"	 => 	34, 
		"intergenic_variant"	 => 	35, 
	}
	@@SEVERITY.default = 0
	
	def self.test_annot()
		
		
		vepa = VepAnnotation.new({})
		vepa.store("tmp/6_2016-01-08-14-51-42--0100.json.error", VcfFile.find(6))
		#vepa.store_vcf("tmp/6_2016-01-08-14-20-02--0100.vcf.error", VcfFile.find(6))
		return true
		
		# vcf = VcfFile.find(118)
		# ap = AquaAnnotationProcess.new(118, [AnnovarAnnotation, SnpEffAnnotation, VariantEffectPredictorAnnotation] )
		ap = AquaAnnotationProcess.new(6)
		ap.start([VepAnnotation])
		vepa = VepAnnotation.new({})
	end
	
	# If the initilizer is overwritten a call to super is neccessary to setup the VCFHEADER variable to parse a Vcf file. 
	def initialize(opts = {})
		super # neccessary to setup @VCFHEADER
		## check setup vep file
	end
	
	def self.get_executable
		self.get_script
	end
	
	def self.get_script
		ensversion = VepAnnotation.config("ensembl_version")
		species = VepAnnotation.config("species").map{|name, build| "#{name}_#{build}"}.sort.join("-")
		@@VEPEXECUTE = File.join(Rails.root, "tmp", "aqua_vep_#{ensversion}_#{species}.sh")
		@@VEPEXECUTE
	end
	
	
	def self.ready?
		ready = super
		ready && File.exist?(VepAnnotation.get_script)
	end

	# Load the configuration accoring to the Rails environment that we run under.
	def self.config(field)
		if @@CONFIGCACHE[field].nil? then
			conf = load_config()
			raise "Field #{field} not found in config for environment #{Rails.env}" if conf[field].nil?
			template = conf[field]
			if template.is_a?(Array) then
				ret = template.map{|x| ERB.new(x.to_s).result(binding)}
			elsif template.is_a?(Hash) then
				ret = Hash[template.map{|k,v| [k, ERB.new(v.to_s).result(binding)]}]
			else
				ret = ERB.new(template.to_s).result(binding)
			end
			@@CONFIGCACHE[field] = ret
		else
			ret = @@CONFIGCACHE[field]
		end
		ret
	end
	
	def self.load_config(force = false)
		if @@VEPCONFIG.nil? or force then
			yaml = File.join(Rails.root, "extras", "snupy_again", "aqua", "annotations" ,"vep", "vep_config.yaml")
			raise "config vep_config.yaml not found" unless File.exists?(yaml)
			
			conf = YAML.load(File.open(yaml).read)
			raise "Config Environment not configured for #{Rails.env}" if conf[Rails.env].nil?
			@@VEPCONFIG = conf[Rails.env]
		end
		@@VEPCONFIG
	end
	
		# Executes the acutal annotation using VEP.
	# The VEP configuration is given by.... 
	# == VEP Options
	# [symbol] annotate with gene symbol
	# [,,,] ...
	## wen need to consider this link here
	## http://uswest.ensembl.org/info/docs/variation/vep/vep_formats.html#vcf
	def perform_annotation(file_path, input_vcf)
		d "VEP WILL ANNOTATE: #{file_path}"
		d "Organism: #{input_vcf.organism.id}"
		d "VCFID: #{input_vcf.id}"
		begin
			species = input_vcf.organism.name
			species_name = species.downcase.gsub(" ", "_")
			if VepAnnotation.config("ensembl_version").to_i > 75 then
				species_name += "_merged" if species == "homo_sapiens" || species == "mus_musculus"
			end
			output_file = File.join(Rails.root, "tmp", "#{File.basename(file_path,".vcf")}.#{VepAnnotation.config("format")}")
			d "VEP OUTPUT: #{output_file}"
			if File.exists?(output_file) then
				File.rename(output_file, "#{output_file}.bak")
			end
			log_file = File.join(Rails.root, "log", "vep_annotation.log")
			error_log_file = File.join(Rails.root, "log", "vep_annotation.error.log")
			if Rails.env == "development" then
				success = system("bash #{VepAnnotation.get_script} -d -i \"#{file_path}\" -o \"#{output_file}\" -s \"#{species_name}\" -f #{VepAnnotation.config("format")} 2>#{error_log_file} 1>#{log_file}")
			else
				success = system("bash #{VepAnnotation.get_script} -i \"#{file_path}\" -o \"#{output_file}\" -s \"#{species_name}\"    -f #{VepAnnotation.config("format")} 2>#{error_log_file} 1>#{log_file}")
			end
			self.class.log_info("VEP process succesfull?: #{success}")
			if !success then
				if File.exist?(error_log_file) then
					raise Exception.new("VEP Annotation Process Failed.(LOG: #{File.open(error_log_file, "r").read})")
				else
					raise Exception.new("VEP Annotation Process Failed for some unknown reason and without a log.")
				end
			else # check if the output file exists - because if the input file didnt have and variations there is no output file but there should be
				if (!File.exists?(output_file)) then
					self.class.log_info "VEP Output (#{output_file}) does not exist, but process was successfull. Maybe the INPUT is empty - creating empty output file"
					FileUtils.touch(output_file)
				end
			end
			d "Annotation finished at #{Time.now}"
		rescue => e
			self.class.log_fatal("#{e.message}: #{e.backtrace.pretty_print_inspect}")
			raise
		end
		return output_file
	end
	
	def find_field(hsh, *fields)
		return nil if hsh.nil?
		if hsh.is_a?(Array)
			return hsh.map{|x| find_field(x, fields)}
		else
			fields = [fields] unless fields.is_a?(Array)
			ret = fields.flatten.map{|f|
				hsh[f]
			}
		end
		ret
	end
	
	def fill_template1(template, attrs)
		if template.is_a?(Array) then
			return template.map{|tmpl| fill_template(tmpl, attrs)}
		end
		ret = []
		obj = template.dup
		myattrs = attrs.dup
		consequences = myattrs["consequence_terms"]
		myattrs.delete("consequence_terms")
		obj.merge!(myattrs)
		consequences.each do |cons|
			consobj = obj.dup
			consobj["consequence"] = cons
			ret << consobj
		end
		ret
	end
	
	def fill_template(template, attrs)
		if template.is_a?(Array) then
			return template.map{|tmpl| fill_template(tmpl, attrs)}
		end
		ret = []
		# tmp = template.merge(attrs)
		attrs["consequence_terms"].map{|cons|
			tmp = template.merge(attrs)
			tmp["consequence_terms"] = cons
			ret << tmp
		}
		
		#obj = template.dup
		#myattrs = attrs.dup
		#consequences = myattrs["consequence_terms"]
		#myattrs.delete("consequence_terms")
		#obj.merge!(myattrs)
		#consequences.each do |cons|
		#	consobj = obj.dup
		#	consobj["consequence"] = cons
		#	ret << consobj
		#end
		ret
	end
	
	def store(result, vcf)
		if VepAnnotation.configuration[:output] == :vcf then
			store_vcf(result, vcf)
		elsif VepAnnotation.configuration[:output] == :json
			store_json(result, vcf)
		else
			raise "Unknown format to store VCF."
		end
	end
	
		# Maps each line of the VEP Vcf to a new database object.
	# Therefore the CSQ field of the INFO attribute needs to be parsed. 
	def store_json(result, vcf)
		begin
			organism_id = vcf.organism.id
			fin = File.new(result, "r")
			vcfparser = Vcf.new()
			store_begin = Time.now
			
			num_annotation = 0
			write_buffer = []
			lineno = 0
			
			accepted_attribues = Hash[Vep.attribute_names.map{|x| [x,true]}]
			accepted_attribues.default = false
			fin.each_line do |jsonstr|
				lineno += 1
				# VEP might not yield consequences for every variation for all transcript sets
				# so we need to check which variants have a consequence in which transcript set 
				# and add artifical (empty?) records to the database 
				sources = {
					"Ensembl" => false,
					"RefSeq" => false
				}
				# annotrec = JSON.load(jsonstr)
				annotrec = Oj.load(jsonstr) # 100% faster
				variation_id = annotrec["id"]
				variation_id = annotrec["input"].split("\t")[7].split("=")[1] if variation_id.nil?
				# if !vcfparser.parse_line(annotrec["input"]) then # using this will take 25% more time
				if variation_id.nil? then
					self.class.log_info "[VEP] Vaiation ID could not be infered from input. "
					raise "Variation ID could not be infered from inputs because its invalid VCF format in #{result}"
				else
					variation_id = variation_id.to_i
				end
				
				raise "INVALID variation ID in #{result}" if variation_id.to_i == 0 or variation_id.nil?
				if !annotrec["colocated_variants"].nil? then
					minor_allele, minor_allele_freq = (find_field(annotrec["colocated_variants"], "minor_allele", "minor_allele_freq") || []).reject{|x,y| x.nil?|y.nil?}.first
					exac_adj_allele, exac_adj_maf = (find_field(annotrec["colocated_variants"], "exac_adj_allele", "exac_adj_maf") || []).reject{|x,y| x.nil?|y.nil?}.first
					dbsnps = find_field(annotrec["colocated_variants"], "id", "allele_string", "somatic", "phenotype_or_disease", "pubmed", "clin_sig")
				else 
					minor_allele, minor_allele_freq = nil
					exac_adj_allele, exac_adj_maf = nil
					dbsnps = [[nil, nil, 0, 0, 0, 0]]
				end
				# collapse the dbsnp ids into one row.
				dbsnps = dbsnps.inject({
					dbsnp: [],
					dbsnp_allele: [],
					somatic: [],
					phenotype_or_disease: [],
					pubmed: [],
					clin_sig: []
				}){|mem, x|
					if !x[0].nil? then
						mem[:dbsnp] << x[0]
						mem[:dbsnp_allele] << x[1]
						mem[:somatic] << (x[2] || 0)
						mem[:phenotype_or_disease] << (x[3] || 0)
						mem[:pubmed] += x[4].to_s.split(",")
						mem[:clin_sig] += x[5].to_s.split(",")
					end
					mem
				}
				
				dbsnps[:dbsnp] = dbsnps[:dbsnp].flatten.join(",")
				dbsnps[:dbsnp_allele] = dbsnps[:dbsnp_allele].flatten.join(",")
				dbsnps[:somatic] = dbsnps[:somatic].flatten.max
				dbsnps[:phenotype_or_disease] = dbsnps[:phenotype_or_disease].flatten.max
				dbsnps[:pubmed] = dbsnps[:pubmed].flatten.map{|x| x.gsub(/[\[\]]/, "").strip}.uniq
				dbsnps[:clin_sig] = dbsnps[:clin_sig].flatten.map{|x| x.gsub(/[\[\]]/, "").strip}.uniq
				dbsnps[:pubmed] = dbsnps[:pubmed].join(",") # TODO uncommend
				dbsnps[:clin_sig] = dbsnps[:clin_sig].flatten.sort.uniq.join(",")
				dbsnps[:pubmed] = nil if dbsnps[:pubmed] == "" or dbsnps[:pubmed] == []
				dbsnps[:clin_sig] = nil if dbsnps[:clin_sig] == "" or dbsnps[:clin_sig] == []
				# d dbsnps
				#dbsnps.each do |dbsnp, dbsnp_allele, somatic, phenotype_or_disease, pubmed, clin_sig|
					vepattr_template = {
						variation_id: variation_id,
						organism_id: organism_id, 
					#	dbsnp: dbsnp,
					#	dbsnp_allele: dbsnp_allele,
					#	pubmed: pubmed,
					#	clin_sig: clin_sig,
					#	somatic: somatic == 1,
					#	phenotype_or_disease: phenotype_or_disease == 1,
						minor_allele: minor_allele, 
						minor_allele_freq: minor_allele_freq, 
						exac_adj_allele: exac_adj_allele, 
						exac_adj_maf: exac_adj_maf,
						most_severe_consequence: annotrec["most_severe_consequence"]
					}.merge(dbsnps)
					
					vepattrs = []
					# create attributes for transcripts and intergenic variants
					# we only store regulatory features for CNV
					if annotrec["variant_class"] == "CNV" then
						if self.class.configuration[:include_regulatory] then
							cons2parse = [annotrec["regulatory_feature_consequences"], annotrec["intergenic_consequences"], annotrec["transcript_consequences"]].flatten
						else
							cons2parse = [annotrec["intergenic_consequences"], annotrec["transcript_consequences"]].flatten
						end
					else
						cons2parse = [annotrec["intergenic_consequences"], annotrec["transcript_consequences"]].flatten
					end
					cons2parse.each do |transcons|
						next if transcons.nil?
						vepattrs += fill_template(vepattr_template, transcons)
						#vepattrs += transcons["consequence_terms"].map{|cons|
						#	tmp = transcons.merge(vepattr_template)
						#	tmp["consequence_terms"] = cons
						#	tmp
						#}.flatten
					end
					#pp vepattrs
					#pp annotrec
					#raise "nonono"
					
					# ifa available also create attributes for TFBS motifs
					if !annotrec["motif_feature_consequences"].nil? then
						annotrec["motif_feature_consequences"].each do |motifcons|
							motif_attrs = fill_template(vepattr_template, motifcons)
							motif_attrs.each do |ma|
								ma["source"] = "Ensembl" # set it to Ensembl so we can use Vep::Ensembl
								ma["biotype"] = "tf_binding_site"
							end
							vepattrs += motif_attrs
						end
					end
					
					# check if consequence field is set
					vepattrs.each do |vepattr|
						vepattr["consequence"] = (vepattr["consequence_terms"] || vepattr[:most_severe_consequence]) if vepattr["consequence"].nil?
						vepattr["source"] = "Ensembl" if vepattr["source"].nil?
						sources[vepattr["source"]] = true
					end
					
					# make sure to set to set transcript ID
					vepattrs.each do |vepattr|
						vepattr["transcript_id"] = (vepattr["transcript_id"] || vepattr["regulatory_feature_id"])
						# check if variant allele is minor allele
					# TODO: Handle deletions and insertions correctly.
						vepattr["allele_is_minor"] = vepattr["variant_allele"] == minor_allele unless minor_allele.nil?
					end
					
					# post processing of attribute mapping
					if annotrec["variant_class"] == "CNV"
						vepattrs = post_process_cnv(vepattrs, accepted_attribues, annotrec, variation_id, organism_id)
					else
						vepattrs = post_process_snp_indel(vepattrs, accepted_attribues)
					end
					
					## handle cases where only one transcript set prediceted a consequence
					## this is likely a bug to be fixed but in VEP 84 this can happen
					## This VCF entry is an example which only yield consequences for Ensembl transcripts:
					##     1	220603310	144658	TGTGA	T	100	PASS	VID=144658	.	.
					if (!sources["Ensembl"] || !sources["RefSeq"]) && annotrec["variant_class"] != "CNV" then
						d "Somthing is wrong with the source..."
						d sources
						empty_record = {
							variation_id: variation_id,
							organism_id: organism_id, 
							consequence: "sequence_variant",
							most_severe_consequence: "sequence_variant"
						}
						if sources["Ensembl"] && !sources["RefSeq"] then
							empty_record["source"] = "RefSeq"
						elsif !sources["Ensembl"] && sources["RefSeq"] then
							empty_record["source"] = "Ensembl"
						elsif !sources["Ensembl"] && !sources["RefSeq"] then
							self.class.log_error "No consequnce predicted for #{variation_id} for #{jsonstr}"
							empty_record["source"] = "Ensembl"
						else
							empty_record["source"] = "Ensembl"
						end
						accepted_attribues.each do |a|
								empty_record[a] = nil if empty_record[a].nil? # fill them with nil values - make sure the key exists in the attribute hash
						end
						vepattrs << empty_record
					end
					
					# vepobjs = vepattrs.map{|attrs| Vep.new(attrs)} # do not initiate the model, Hashes and a template is enough for mass_insert
					vepobjs = vepattrs
					write_buffer += vepobjs
					num_annotation += vepobjs.size
				#end # end of each dbsnp id
				#print("#{lineno} lines (#{(lineno/(Time.now-store_begin)).round(3)})...\r")
				#next
				print("#{num_annotation} records (#{(num_annotation/(Time.now-store_begin)).round(0)} rps)...\r")
				if write_buffer.size >= 11000
					SnupyAgain::DatabaseUtils.mass_insert(write_buffer, false, 1100, Vep, true)
					write_buffer = []
				end
			end # end of each_line
			if write_buffer.size > 0
				SnupyAgain::DatabaseUtils.mass_insert(write_buffer, false, 1100, Vep, true)
			end # end of empty buffer
			# return write_buffer
			self.class.log_info("VEP-ANNOTATION  DONE for VcfFile: #{vcf.name}. #annotations: #{num_annotation}")
			d "Done Storing VEP Annotations at #{Time.now} after #{(Time.now-store_begin).to_i} seconds..."
			d "Archiving annotation"
			# system "gzip #{result}"
			return true
		rescue => e
			# Erase all annotations that made it to the database
			self.class.log_fatal("ERROR DURING VEP JSON store #{e.message}: #{e.backtrace.join("\n")}")
			vcf.status = :ERROR
			vcf.save!
			raise
		end
		return true
	end
	
	def get_vep_columns()
		return nil if @VCFHEADER.nil?
		desc = @VCFHEADER["INFO"]["CSQ"]["Description"]
		vepcols = desc.scan(/Format: (.*)$/).flatten.first.split("|")
		vepcols
	end
	
	def get_vep_record(vepline, vepcols = get_vep_columns())
		veprec = vepline.split("|", -1)
		veprec = Hash[vepcols.each_with_index.map{|col, i|
										val = veprec[i].to_s.split("&")
										val = val[0] if val.size <= 1
										[col, val]
									}]
		veprec["SYMBOL"] = veprec["HGNC"] if veprec["SYMBOL"].nil?
		veprec
	end	
	
	def post_process_snp_indel(vepattrs, accepted_attribues)
		vepattrs.each do |vepattr|
			# Domains are hashes - make them simler strings
			if !vepattr["domains"].nil? then
				if vepattr["domains"].is_a?(Array) then
					if vepattr["domains"].size > 0
						vepattr["domains"] = vepattr["domains"].map{|x| "#{x["db"]}:#{x["name"]}"}.sort.uniq.join(",")
					else
						vepattr["domains"] = nil
					end
				end
			end
			
			# exons and intrn numbers are mapped to a common attribute
			numbr = (vepattr["exon"] || vepattr["intron"])
			if !numbr.nil? then
				numbr1, numbr2 = numbr.gsub("-", ".").split("/").map(&:to_f)
			else
				numbr1, numbr2 = nil
			end
			vepattr["numbers1"] = numbr1
			vepattr["numbers2"] = numbr2
			
			# set high inf pos
			vepattr["high_inf_pos"] = vepattr["high_inf_pos"].to_s == "Y"
			
			# canonical 
			vepattr["canonical"] = vepattr["canonical"] == 1
			
			vepattr["trembl_id"] = vepattr["trembl"] if vepattr["trembl_id"].nil?
			
			vepattr["hgvsc"] = (vepattr["hgvsc"].nil?)?nil:vepattr["hgvsc"].split(".", 2)[1] # remove the transcript identifier from the hgvs annotation
			vepattr["hgvsp"] = (vepattr["hgvsp"].nil?)?nil:vepattr["hgvsp"].split(".", 2)[1] # because it is redunant
			
			# remove attributes that are not part of the model
			vepattr = vepattr.keep_if{|k,v| accepted_attribues[k.to_s]}
			#vepattr.keys.select{|k| !accepted_attribues[k.to_s]}.each do |invalid_attr_name|
			#	vepattr.delete(invalid_attr_name)
			#end
		end # end of post processing
		vepattrs
	end
	
	# this method reduces the amount of available annotation significantly
	# this is useful for CNV annotations as they result in many meaningless annotations
	# because the most_serve_consequence is calculated on a per-variant basis, but for CNVs 
	# we want to only see the most severe mutation for one gene
	# it should also reduce the amount of annotations, 87 CNVs can result in 150.000 annotations
	# This is too much to handle for users. When only affected genes are of interest.
	# Therefore: For each CNV-gene interaction we only store a condensed set of annotations
	# transcript_id: is set to null
	# protein_id is set to null
	# canonical: is 1 if CNV hits canonical transcript
	# CCDS: takes the value of the canonical transcript, or null if no canonical transcript is hit
	# uniparc, swissprot, trembl_id etc: set to null
	# numbers1/2: NULL
	# distance: NULL
	# domains: merged
	# bp_overlap: Maximum bp overlap
	# percentage_overlap: percentage overlap of longest overlap
	# consequence: set to copy_number_variation
	# most_severe_consequence: set to most severe consequence of a variant in that gene (not in all genes affected by CNV)
	#
	# ## SKIP IF CNV too long
    ## We set the threshold to 225kb
    # 99% of the registered CNV are below the threshold of 225kbkb
    # Data: http://dgv.tcag.ca/dgv/docs/Stringent.Gain+Loss.hg19.2015-02-03.txt
    # Read the data with R
    # Remove small events < 1kb
    # calculate the quantiles on end-start
	def post_process_cnv(vepattrs, accepted_attribues, annotrec, variation_id, organism_id)
		
		# In case the CNV is too long, we will simply return a placeholder record
		# On really long CNV we will also add a consequence that does not play well with the default filter values
		# so users wont be confused and we dont get CNV grouped wrongly
		if (annotrec["end"].to_i-annotrec["start"].to_i).abs > VepAnnotation.config("cnv_threshold_too_long").to_i then
			ret = %w(Ensembl RefSeq).map do |source |
				{
						variation_id: variation_id,
						organism_id: organism_id,
						source: source,
						gene_id: nil,
						transcript_id: nil,
						gene_symbol: nil,
						most_severe_consequence: "very_long_copy_number_variation",
						consequence: "copy_number_variation(unspecific)",
						canonical: nil
				}
			end
			return ret
		elsif (annotrec["end"].to_i-annotrec["start"].to_i).abs > VepAnnotation.config("cnv_threshold").to_i then
			ret = %w(Ensembl RefSeq).map do |source |
				{
			        variation_id: variation_id,
			        organism_id: organism_id,
			        source: source,
			        gene_id: nil,
			        transcript_id: nil,
			        gene_symbol: nil,
			        most_severe_consequence: "long_copy_number_variation",
			        consequence: "copy_number_variation",
			        canonical: nil
		        }
			end
			return ret
		end
		
		
		vepattrs = post_process_snp_indel(vepattrs, accepted_attribues)
		allattrs = %w(variation_id organism_id impact consequence source biotype most_severe_consequence dbsnp dbsnp_allele minor_allele minor_allele_freq exac_adj_allele exac_adj_maf gene_id transcript_id gene_symbol ccds cdna_start cdna_end cds_start cds_end canonical protein_id protein_start protein_end amino_acids codons numbers1 numbers2 hgvsc hgvsp hgvs_offset distance trembl_id uniparc swissprot polyphen_prediction polyphen_score sift_prediction sift_score domains pubmed somatic gene_pheno phenotype_or_disease allele_is_minor clin_sig motif_feature_id motif_name high_inf_pos motif_pos motif_score_change created_at updated_at bp_overlap percentage_overlap)
		attrs2keep = %w(variation_id organism_id source gene_id transcript_id gene_symbol ccds canonical biotype)
		attrs2keep = Hash[attrs2keep.map{|a| [a, true] }]
		attrs2keep.default = false
		
		# create new vep attrs which holds one record per gene symbol
		ret = {}
		vepattrs.each do |vepattr|
			# for intergenic variant prediction both transcript and gene is nil
			k = [(vepattr["gene_id"] || vepattr["transcript_id"]), vepattr["variation_id"]]
			ret[k] = [] if ret[k].nil?
			ret[k] << vepattr
		end # end of post processing
		
		ret.keys.each do |k|
			max_bp, max_percentage = ret[k].map{|rec| [(rec["bp_overlap"] || 0), (rec["percentage_overlap"] || 0)]}.max
			# next if max_bp.nil? # overlap can be 0 for upstream/downstream and intergenic variants
			
			my_most_severe = find_most_severe(ret[k])
			summarized_record = ret[k].select{|rec| rec["canonical"]}.first
			summarized_record = ret[k].first if summarized_record.nil?
			summarized_record = summarized_record.dup
			
			summarized_record.keys.each do |a|
				summarized_record[a] = nil unless attrs2keep[a] or attrs2keep[a.to_s]
			end
			summarized_record["ccds"] = nil unless summarized_record["canonical"]
			summarized_record["biotype"] = nil unless summarized_record["canonical"]
			summarized_record["transcript_id"] = nil unless summarized_record["gene_id"].nil? or summarized_record["transcript_id"].nil? # gene id is nil for regulatory regions 
			summarized_record["consequence"] = "copy_number_variation"
			summarized_record["most_severe_consequence"] = my_most_severe
			
			summarized_record["bp_overlap"] = max_bp
			summarized_record["percentage_overlap"] = max_percentage
			
			summarized_record.delete(:most_severe_consequence) if summarized_record["most_severe_consequence"] != summarized_record[:most_severe_consequence]
			ret[k] = summarized_record
		end
		ret = ret.values
		
		## remove CNV records that are too long
		
		
		ret
	end
	
	def find_most_severe(vepattrs)
		ret = vepattrs
		ret = vepattrs.map{|x|
			x = (x["consequence"] || x[:consequence]) if x.is_a?(Hash)
			x
		}
		ret.sort{|x, y|
			@@SEVERITY[x] <=> @@SEVERITY[y]
		}.first
	end
	
	def store_vcf(result, vcf)
		organism_id = vcf.organism.id
		veprec = {}
		begin
			fin = File.new(result, "r")
			num_annotation = 0
			write_buffer = []
			lineno = 0
			store_begin = Time.now
			fin.each_line do |line|
				parse_vcf(line) do |rec|
					vepattrs = []
					lineno += 1
					# next unless lineno == 9
					variation_id = rec[:info]["VID"].to_i
					raise "No variation ID found in VCF file #{result} - cant proceed to store" if variation_id == 0 
					rec[:info]["CSQ"].split(",").each do |vepline|
						veprec = get_vep_record(vepline)
						veprec["Consequence"] = [veprec["Consequence"]] unless veprec["Consequence"].is_a?(Array)
						veprec["Existing_variation"] = [veprec["Existing_variation"]] unless veprec["Existing_variation"].is_a?(Array)
						veprec["Consequence"].each do |cons|
							# let us skip regulatory variants, because we dont parse them in the JSON format and they are kinda useless for WES data...
							next if cons == "regulatory_region_variant"
							#veprec["Existing_variation"].each do |rsid|
								vepattr = {
									:id => veprec["id"],
									:variation_id => variation_id,
									:organism_id => organism_id,
									:impact => veprec["IMPACT"],
									:consequence => cons,
									:source => veprec["SOURCE"],
									:biotype => veprec["BIOTYPE"],
									:most_severe_consequence => veprec["most_severe_consequence"],
									# :dbsnp => rsid,
									:dbsnp => veprec["Existing_variation"].join(","),
									:dbsnp_allele => veprec["dbsnp_allele"],
									:minor_allele => veprec["GMAF"].to_s.split(":")[0],
									:minor_allele_freq => veprec["GMAF"].to_s.split(":")[1],
									
									:exac_adj_allele => veprec["ExAC_Adj_MAF"].to_s.split(":")[0],
									:exac_adj_maf => veprec["ExAC_Adj_MAF"].to_s.split(":")[1],
									:gene_id => veprec["Gene"],
									:transcript_id => veprec["Feature"],
									:gene_symbol => veprec["SYMBOL"],
									:ccds => veprec["CCDS"],
									:cdna_start => veprec["cDNA_position"],
									:cdna_end => veprec["cDNA_position"],
									:cds_start => veprec["CDS_position"],
									:cds_end => veprec["CDS_position"],
									:canonical => veprec["CANONICAL"].to_s == "YES",
									:protein_id => veprec["ENSP"],
									:protein_start => veprec["Protein_position"],
									:protein_end => veprec["Protein_position"],
									:amino_acids => veprec["Amino_acids"],
									:codons => veprec["Codons"],
									:numbers1 => nil,
									:numbers2 => nil,
									:hgvsc => (veprec["HGVSc"].nil?)?nil:veprec["HGVSc"].split(".", 2)[1], # remove the transcript identifier from the hgvs annotation
									:hgvsp => (veprec["HGVSp"].nil?)?nil:veprec["HGVSp"].split(".", 2)[1], # because it is redunant
									:hgvs_offset => veprec["HGVS_OFFSET"],
									
									:distance => veprec["DISTANCE"],
									:trembl_id => veprec["TREMBL"], 
									:uniparc => veprec["UNIPARC"],
									:swissprot => veprec["SWISSPROT"],
									:polyphen_prediction => veprec["PolyPhen"].to_s.split("(")[0],
									:polyphen_score => ((veprec["PolyPhen"] || "").scan(/\((.*)\)/).flatten.first || 1).to_f,
									:sift_prediction => veprec["SIFT"].to_s.split("(")[0],
									:sift_score => ((veprec["SIFT"] || "").scan(/\((.*)\)/).flatten.first || 1).to_f,
									:domains => veprec["DOMAINS"],
									:somatic => veprec["SOMATIC"],
									:gene_pheno => veprec["GENE_PHENO"],
									:clin_sig => veprec["CLIN_SIG"],
									:pubmed => veprec["PUBMED"],
									:phenotype_or_disease => veprec["PHENO"],
									:motif_feature_id => veprec["motif_feature_id"],
									:motif_name => veprec["MOTIF_NAME"],
									:high_inf_pos => veprec["HIGH_INF_POS"].to_s == "Y",
									:motif_pos => veprec["MOTIF_POS"],
									:motif_score_change => veprec["MOTIF_SCORE_CHANGE"]
								}
								if !(veprec["EXON"] || veprec["INTRON"]).nil? then
									numbr1, numbr2 = (veprec["EXON"] || veprec["INTRON"]).split("/")
									vepattr[:numbers1] = numbr1
									vepattr[:numbers2] = numbr2
								end
								vepattr[:source] = "JASPAR" if cons == "TF_binding_site_variant"
								vepattr[:allele_is_minor] = veprec["Allele"] == vepattr[:minor_allele]
								if !vepattr[:domains].nil? and vepattr[:domains].size > 0
									vepattr[:domains] = vepattr[:domains].join(",") if vepattr[:domains].is_a?(Array)
								end
								if !vepattr[:pubmed].nil? and vepattr[:pubmed].size > 0
									vepattr[:pubmed] = vepattr[:pubmed].join(",") if vepattr[:pubmed].is_a?(Array)
								end
								if !vepattr[:clin_sig].nil? and vepattr[:clin_sig].size > 0
									vepattr[:clin_sig] = vepattr[:clin_sig].join(",") if vepattr[:clin_sig].is_a?(Array)
								end
								vepattrs << vepattr
							#end # end of each existing variation
						end # end of each consequence
					end # end of CSQ split
					vepobjs = vepattrs.map{|attrs| Vep.new(attrs)}
					write_buffer += vepobjs
					num_annotation += vepobjs.size
					print("#{num_annotation} records...\r")
					if write_buffer.size > 1100 
						SnupyAgain::DatabaseUtils.mass_insert(write_buffer, false, 10000, Vep)
						write_buffer = []
					end
				end # end of parse line
			end # end of each line
			if write_buffer.size > 0 
				SnupyAgain::DatabaseUtils.mass_insert(write_buffer, false, 10000, Vep)
			end
			self.class.log_info("VEP-ANNOTATION  DONE for VcfFile: #{vcf.name}. #annotations: #{num_annotation}")
			d "Done Storing VEP Annotations at #{Time.now}..."
			d "Archiving annotation"
			system "gzip #{result}"
			return true
		rescue => e
			# Erase all annotations that made it to the database
			self.class.log_fatal("ERROR DURING VEP VCF store #{e.message}: #{e.backtrace.join("\n")}")
			vcf.status = :ERROR
			vcf.save!
			raise
		end
		return true
	end
	
	register_tool name: :vep,
								label: "Variant Effect Predictor (v#{VepAnnotation.config("ensembl_version")})", 
								input: :vcf, 
								output: VepAnnotation.config("format").to_sym,
								supports: [:snp, :indel, :cnv],
								organism: [organisms(:human), organisms(:mouse)],
								model: [Vep],
								include_regulatory: false

	
end
