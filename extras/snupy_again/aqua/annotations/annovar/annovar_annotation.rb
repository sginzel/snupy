# == Description
# Performs an annotation using ANNOVAR.

class AnnovarAnnotationException < RuntimeError

end

class AnnovarAnnotation < Annotation

	register_tool name: :annovar,
								label: "Annovar 2015Mar22",
								input: :vcf,
								output: :vcf,
								supports: [:snp, :indel],
								organism: [organisms(:human), organisms(:mouse)],
	                            quantiles: {
		                            Annovar => {
			                            :sift_score => -1,
			                            :polyphen2_hdvi_score => 1,
			                            :polyphen2_hvar_score => 1,
			                            :lrt_score => 1,
			                            :mutation_taster_score => 1,
			                            :mutation_assessor_score => 1,
			                            :fathmm_score => 1,
			                            :radial_svm_score => 1,
			                            :lr_score => 1,
			                            :vest3_score => 1,
			                            :cadd_raw => 1,
			                            :cadd_phred => 1,
			                            :gerp_rs => 1,
			                            :phylop46way_placental => 1,
			                            :phylop100way_vertebrate => 1,
			                            :siphy_29way_logOdds => 1,
			                            :gerp_gt2 => 1,
			                            :genome_2014oct => -1,
			                            :exac_all => -1
		                            }
	                            },
								model: [Annovar]

	@@ANNOVAREXECUTE =  File.join(Rails.root, "tmp", "aqua_annovar_exec.sh")
	# @@ANNOVARERRORLOGER = Logger.new(File.join( Rails.root, "log", "annovar_annotation.error.log"),1,5242880)
	# @@ANNOVARLOGER = Logger.new(File.join( Rails.root, "log", "annovar_annotation.log"),1,5242880)
	
	# manually derived from sequence ontology
	@@ANNOVARSO = {
		"unknown" => {
			:so_name=>"sequence_variant", 
			:so_id=>"SO:0001060"}, 
		"stoploss" => {
			:so_name=>"stop_lost", 
			:so_id=>"SO:0001578"}, 
		"nonsynonymous SNV" => {
			:so_name=>"missense_variant", 
			:so_id=>"SO:0001583"}, 
		"stopgain" => {
			:so_name=>"stop_gained", 
			:so_id=>"SO:0001587"}, 
		"frameshift block substitution" => {
			:so_name=>"frameshift_variant", 
			:so_id=>"SO:0001589"},
		"ncRNA_exonic" => {
			:so_name=>"non_coding_transcript_variant", 
			:so_id=>"SO:0001619"}, 
		"ncRNA_intronic" => {
			:so_name=>"non_coding_transcript_variant", 
			:so_id=>"SO:0001619"}, 
		"UTR5" => {
			:so_name=>"5_prime_UTR_variant", 
			:so_id=>"SO:0001623"}, 
		"UTR3" => {
			:so_name=>"3_prime_UTR_variant", 
			:so_id=>"SO:0001624"}, 
		"intronic" => {
			:so_name=>"intron_variant", 
			:so_id=>"SO:0001627"}, 
		"intergenic" => {
			:so_name=>"intergenic_variant", 
			:so_id=>"SO:0001628"}, 
		"splicing" => {
			:so_name=>"splice_region_variant", 
			:so_id=>"SO:0001630"}, 
		"upstream" => {
			:so_name=>"upstream_gene_variant", 
			:so_id=>"SO:0001631"}, 
		"downstream" => {
			:so_name=>"downstream_gene_variant", 
			:so_id=>"SO:0001632"}, 
		"nonframeshift block substitution" => {
			:so_name=>"inframe_variant", 
			:so_id=>"SO:0001650"}, 
		"exonic" => {
			:so_name=>"exon_variant", 
			:so_id=>"SO:0001791"}, 
		"synonymous SNV" => {
			:so_name=>"synonymous_variant", 
			:so_id=>"SO:0001819"}, 
		"nonframeshift insertion" => {
			:so_name=>"inframe_insertion", 
			:so_id=>"SO:0001821"}, 
		"nonframeshift deletion" => {
			:so_name=>"inframe_deletion", 
			:so_id=>"SO:0001822"}, 
		"frameshift insertion" => {
			:so_name=>"frameshift_elongation",
			:so_id=>"SO:0001909"}, 
		"frameshit deletion" => {
			:so_name=>"frameshift_truncation", 
			:so_id=>"SO:0001910"}
		}
		@@ANNOVARSO.default = {
			:so_name=>"unknown annovar annotation", 
			:so_id=>"SO:0000000"
		}

	# If the initilizer is overwritten a call to super is neccessary to setup the VCFHEADER variable to parse a Vcf file.
	def initialize(opts={})
		super # neccessary to setup @VCFHEADER
		begin
			d "I am born to be ANNOVAR!"
			raise "AnnovarAnnotation: execute script dont exist, plesase run bundle exec rake aqua:setup[annovar] and bundle exec rake aqua:migrate[annovar]" unless self.class.ready?
		rescue => e
			d "[ERROR-ANNOVARANNOTATION-INITIALIZE-#{Time.now}] #{e.message}: #{e.backtrace}"
		end
	end

	def self.ready?
		#return false if 1 == 1
		satisfied = super
		satisfied && File.exist?(@@ANNOVAREXECUTE)
	end

	# Load the configuration accoring to the Rails environment that we run under.
	def self.load_configuration_variable(field)
		configuration_file = File.join(Rails.root, "extras", "snupy_again", "aqua", "annotations" ,"annovar", "annovar.yaml")
		if !File.exists?(configuration_file) then
			raise "annovar.yaml - No such file or directory  "
		else
			conf = YAML.load(File.open(configuration_file).read)
			raise "Field #{field} not found in config file #{configuration_file} for environment #{Rails.env}" if conf[Rails.env][field].nil?
			template = conf[Rails.env][field]
			ret = ERB.new(template.to_s).result(binding)
			return ret
		end
	end

	# Executes the actual annotation using SnpEff.
	# The SnpEff configuration is given by....
	# == SnpEff Options
	# [symbol] annotate with gene symbol
	# [,,,] ...
	def perform_annotation(file_path, input_vcf)
		d "************ start perform_annotation ***********"
		d "ANNOVAR WILL ANNOTATE: #{file_path}"
		d "Organism: #{input_vcf.organism.id} - #{input_vcf.organism.name}"
		output_annovar_file = ""
		
		begin
			organism = input_vcf.organism.name.to_s
			organism = organism.downcase.gsub(" ", "_")
			
			file_path_org = file_path
			file_path = convert_input_to_annovar_format(file_path)
			
			output_annovar_file = File.join(Rails.root, "tmp", "#{input_vcf.id}_#{File.basename(file_path,".avinput")}.annovar")
			
			log_file = File.join( Rails.root, "log", "annovar_annotation.log")
			
			success = system("bash #{@@ANNOVAREXECUTE} -i \"#{file_path}\" -o \"#{output_annovar_file}\" -t \"#{organism}\" 2>&1 1>#{log_file}")
			
			if !success then
				if File.exist?(log_file) then
					raise AnnovarAnnotationException.new("ANNOVAR Annotation Process Failed.(LOG: #{File.open(log_file, "r").read[0...1024]}...)")
				else
					raise AnnovarAnnotationException.new("ANNOVAR Annotation Process Failed for some unknown reason and without a log.")
				end
			end
			
			
			### let us not be too harsh with the invalid inputs. We can just store them as empty annotations and let the user deal with it.
			### If annovar cannot handle them we shouldn't pretend we can.
			invalid_inputs = 0
			if (File.exists?("#{output_annovar_file}.invalid_input")) then
				invalid_inputs = (`cat #{output_annovar_file}.invalid_input | grep -v '#' | wc -l`.strip)
			end
			#if !invalid_inputs.nil? then
			#	if invalid_inputs.to_i > 0 then
			#		raise AnnovarAnnotationException.new("ANNOVAR Annotation Process for VcfFile##{input_vcf.id} had invalid input (#{invalid_inputs} lines) (INPUT: #{file_path_org}, CONVERTED:#{file_path}, OUTPUT: #{output_annovar_file})")
			#	else
			#		self.class.log_info("VcfFile##{input_vcf.id} was successfully annotated.")
			#	end
			#else
			#	raise AnnovarAnnotationException.new("cannot determine the number of invalid inputs.")
			#end
			self.class.log_info("VcfFile##{input_vcf.id} was successfully annotated. (#{invalid_inputs} invalid inputs)")
			
			#d "Store performance: #{annotation_performance(t1,Time.now, num_annotation)} seconds pro annotation"
		rescue => e
			self.class.log_fatal("#{e.message}: #{e.backtrace.join("=>")}")
			raise
		end
		d "********** perform_annotation done **************"
		return output_annovar_file
	end
	
	def convert_input_to_annovar_format(file_path)
		annovar_input = file_path + ".avinput"
		
		system "perl #{AnnovarAnnotation.load_configuration_variable("annovar_convert_script")} --format vcf4old --snpqual 0 '#{file_path}' --includeinfo 2>/dev/null | grep -v 'NOTICE:' | cut -f1,2,3,4,5,8 > '#{annovar_input}'"
		return annovar_input if 1 == 1
		# annovar_input = File.new(file_path + ".avinput", "w+")
		File.open(file_path, "r").each_line do |line|
			if line[0] == "#" then
				annovar_input.write(line)
				next
			end
			chr, start, stop, ref, alt, rest = line.split("\t", 6)
			
			raise "Cannot convert multi-allelic mutations" if ref.index(",") or alt.index(",") or ref.index("/") or alt.index("/") 
			
			av_start = start
			av_stop = stop
			av_ref = ref
			av_alt = alt
			
			if ref.length == 1 and alt.length == 1 then
				if av_ref.index("N") or av_alt.index("N") then
					av_ref = av_alt if av_ref == "N"
					av_alt = av_ref if av_alt == "N" 
					self.class.log_error("Variant ID #{rest} contains N-bases and is a SNP.")
				end
			else
				# http://annovar.openbioinformatics.org/en/latest/user-guide/input/
				# if that is not a SNV then we have to convert the indel to AV format 
				# VCF 
				#    AC ACTG
				#    ACTG AC
				# AV Format
				#   - TG
				#   TG -
				if ref.length < alt.length then # insertion
					if alt =~ Regexp.new("^#{ref}") then
						av_alt = alt.gsub(Regexp.new("^#{ref}"), "")
						av_start = start.to_i + ref.length
						av_stop = av_start
						av_ref = "-"
					else # block substituion
						av_stop = av_start.to_i + (av_ref.length - 1)
					end
				else # deletion
					if ref =~ Regexp.new("^#{alt}") then
						av_ref = ref.gsub(Regexp.new("^#{alt}"), "")
						av_start = start.to_i + alt.length
						av_alt = "-"
					else # block substitution
						# where we dont have to do anything....
						av_stop = av_start.to_i + (av_ref.length - 1)
					end
				end
				
				# in some cases insertions and deletions might contain N-nucleotides when the INDEL 
				# contains undetermined bases. For INDELs it should not matter which exact bases there are
				# as long as the number of base pairs is correct. We therefore replace N characters with the 
				# consensus of the sequence and hope for the best.
				if av_ref.index("N") or av_alt.index("N") then
					if av_ref.length > 1 or av_alt.length > 1 then #Indel
						ref_consensus = av_ref.to_s.split("").select{|b| b =~ /[ACGT]/}.sort.reduce(Hash.new(0)){|cnt, b| cnt[b] += 1; cnt}.max_by{|b, cnt|cnt}
						alt_consensus = av_alt.to_s.split("").select{|b| b =~ /[ACGT]/}.sort.reduce(Hash.new(0)){|cnt, b| cnt[b] += 1; cnt}.max_by{|b, cnt|cnt}
						av_ref.gsub!("N", ref_consensus[0]) unless ref_consensus.nil?
						av_alt.gsub!("N", alt_consensus[0]) unless alt_consensus.nil?
						self.class.log_warning("Variant ID #{rest} contains N-bases. We substiuted them for consensus (#{ref} > #{av_ref} | #{alt} > #{av_alt})")
					else # we have a 1bp Insertion/Deletion where the Reference or Alternative is N - so no consensus...
						# just replace the N with C - because for deletions the actual base should not matter
						# and we choose C so no start gain or loss is predicted in the future
						av_ref = "C" if av_ref == "N"
						av_alt = "C" if av_alt == "N"
					end
				end
			end
			annovar_input.write([chr, av_start, av_stop, av_ref, av_alt, rest].join("\t"))
		end
		annovar_input.close()
		annovar_input.path
	end
	
	# re implemented version of store that relies mostly on multianno.csv
	# def store(result, vcf) 
	def store(result, vcf)
		# result = "tmp/-1_-1_2015-11-23-13-06-48--0100.csv.avinput.annovar" if result.to_s == ""
		d "****************** start store ******************"
		num_annotation = 0
		begin
			organism = vcf.organism.name.to_s
			organism = organism.downcase.gsub(" ", "_")
			organism_build = self.class.load_configuration_variable("#{organism}_build")
			
			alias_lookup = build_ensembl_to_alias_lookup(vcf.organism.id)
			
			# add invalid input first
			num_invalid = store_invalid("#{result}.invalid_input", vcf.organism.id)
			if (num_invalid.nil?) then
				self.class.log_info "[ANNOVAR] no invalid_input found for #{result}..."
			else
				if num_invalid > 0 then
					self.class.log_error "[ANNOVAR] #{vcf.id} has #{num_invalid} inputs which were not annotated..."
				end
			end
			
			# d "adding annotations..."
			fin = File.new("#{result}.#{organism_build}_multianno.csv", "r")
			
			annovar_buffer = []
			num_annotation = 0
			header = nil
			fin.each_line do |line|
				next if line =~ /^#/
				if header.nil?
					header = line.strip.split(",")
					next
				end
				rec = CSV.parse_line(line, headers: header, col_sep: ",").to_hash
				# map record to annovar objects
				## split up all fields related to consequence for ensGene and refGene
				%w(Func.refGene Gene.refGene GeneDetail.refGene ExonicFunc.refGene AAChange.refGene 
				   Func.ensGene Gene.ensGene GeneDetail.ensGene ExonicFunc.ensGene AAChange.ensGene).each do |field|
					rec[field] = rec[field].to_s.split(";").map{|x| x.split(",")}.flatten
				end
				# initialize the attribute hash with all the simple keys
				variant_template = map_hash_keys(rec, {
					"variation_id"                    => "Otherinfo",
					"sift_score"                      => "SIFT_score",
					"sift_pred"                       => "SIFT_pred",
					"polyphen2_hdvi_score"            => "Polyphen2_HDIV_score",
					"polyphen2_hdvi_pred"             => "Polyphen2_HDIV_pred",
					"polyphen2_hvar_score"            => "Polyphen2_HVAR_score",
					"polyphen2_hvar_pred"             => "Polyphen2_HVAR_pred",
					"lrt_score"                       => "LRT_score",
					"lrt_pred"                        => "LRT_pred",
					"mutation_taster_score"           => "MutationTaster_score",
					"mutation_taster_pred"            => "MutationTaster_pred",
					"mutation_assessor_score"         => "MutationAssessor_score",
					"mutation_assessor_pred"          => "MutationAssessor_pred",
					"fathmm_score"                    => "FATHMM_score",
					"fathmm_pred"                     => "FATHMM_pred",
					"radial_svm_score"                => "RadialSVM_score",
					"radial_svm_pred"                 => "RadialSVM_pred",
					"lr_score"                        => "LR_score",
					"lr_pred"                         => "LR_repd",
					"vest3_score"                     => "VEST3_score",
					"cadd_raw"                        => "CADD_raw",
					"cadd_phred"                      => "CADD_phred",
					"gerp_rs"                         => "GERP++_RS",
					"gerp_gt2"                        => "gerp++gt2",
					"phylop46way_placental"           => "phyloP46way_placental",
					"phylop100way_vertebrate"         => "phyloP100way_vertebrate",
					"siphy_29way_logOdds"             => "SiPhy_29way_logOdds",
					"genome_2014oct"                  => "1000g2014oct_all",
					"snp138"                          => "snp138",
					"esp6500siv2_all"                 => "esp6500siv2_all",
					"cg69"                            => "cg69",
					"exac_all"                        => "ExAC_ALL"
				}).merge(
							{
									"wgrna_name"                      => (multi_key_entry rec["wgRna"])["Name"],
									"micro_rna_target_score"          => (multi_key_entry rec["targetScanS"])["Score"],
									"micro_rna_target_name"           => (multi_key_entry rec["targetScanS"])["Name"],
									"tfbs_score"                      => (multi_key_entry rec["tfbsConsSites"])["Score"],
									"tfbs_motif_name"                 => (multi_key_entry rec["tfbsConsSites"])["Name"],
									#"genomic_super_dups_score"        => (multi_key_entry rec["genomicSuperDups"])["Score"],
									#"genomic_super_dups_name"         => (multi_key_entry rec["genomicSuperDups"])["Name"],
									"gwas_catalog"                    => (multi_key_entry rec["gwasCatalog"])["Name"],
									"cosmic68_id"                     => (multi_key_entry rec["cosmic68"])["ID"],
									"cosmic68_occurence"              => (multi_key_entry rec["cosmic68"])["OCCURENCE"],
									"variant_clinical_significance"   => (multi_key_entry rec["clinvar_20140929"])["CLINSIG"],
									"variant_disease_name"            => (multi_key_entry rec["clinvar_20140929"])["CLNDBN"],
									"variant_revstat"                 => (multi_key_entry rec["clinvar_20140929"])["CLNREVSTAT"],
									"variant_accession_versions"      => (multi_key_entry rec["clinvar_20140929"])["CLNACC"],
									"variant_disease_database_name"   => (multi_key_entry rec["clinvar_20140929"])["CLNDSDB"],
									"variant_disease_database_id"     => (multi_key_entry rec["clinvar_20140929"])["CLNDSDBID"]
							}
				)
				if !variant_template["variant_disease_name"].nil? then
					variant_template["variant_disease_name"].gsub!("\\x2c", "")
				end
				%w(variant_clinical_significance variant_disease_name variant_revstat variant_accession_versions variant_disease_database_name variant_disease_database_id).each do |k|
					variant_template[k] = variant_template[k].to_s.split(",").uniq.join(",") unless variant_template[k].nil?
					variant_template[k] = nil if variant_template[k] == "."
				end
				variant_template["organism_id"] = vcf.organism.id
				# variation_id = rec["Start"] # TODO CHANGE THIS!!!!
				annot_rec_gene = extract_transcript_consequences(rec, [variant_template], "ref", "refgene")
				annot_rec_gene = extract_transcript_consequences(rec, annot_rec_gene, "ens", "ensembl")
				annot_rec_gene.each do |annotrec|
					annotrec.keys.each do |k|
						annotrec[k] = annotrec[k].force_encoding("utf-8") if annotrec[k].is_a?(String)
					end
				end
				annovars = annot_rec_gene.uniq
				
				annovars.each do |attrs|
					attrs["ensembl_gene_is_refgene_alias"] = false
					attrs["ensembl_transcript_is_refgene_transcript_alias"] = false
					## check if the ensembl transcript and the RefSeq transcript identifiers match...
					if !attrs["ensembl_effect_transcript"].nil? && !attrs["refgene_effect_transcript"].nil? then
						enst_aliases = alias_lookup[attrs["ensembl_effect_transcript"]]
						if !enst_aliases.nil? then
							enst_aliases = enst_aliases.map{|db, aliases| aliases}.flatten
							if enst_aliases.size > 0 then
								attrs["ensembl_transcript_is_refgene_transcript_alias"] = enst_aliases.map{|nm| nm.gsub(/\.[0-9]*$/, "")}.include?(attrs["refgene_effect_transcript"])
							end
						end
					else
						attrs["ensembl_transcript_is_refgene_transcript_alias"] = nil
					end
					## do the same for the ensembl gene identifier
					if !attrs["ensembl_gene"].nil? && !attrs["refgene_gene"].nil? then
						ensg_aliases = alias_lookup[attrs["ensembl_gene"]]
						if !ensg_aliases.nil? then
							ensg_aliases = ensg_aliases.map{|db, aliases| aliases}.flatten
							if ensg_aliases.size > 0 then
								attrs["ensembl_gene_is_refgene_alias"] = ensg_aliases.include?(attrs["refgene_gene"])
							end
						end
					else
						attrs["ensembl_gene_is_refgene_alias"] = nil
					end
				end
				
				#pp annovars.uniq.size
				#annovars.each do |tmp|
				#	puts [tmp["refgene_gene"], tmp["refgene_effect_transcript"],tmp["refgene_annovar_annotation"], tmp["refgene_annotation"],
				#	      tmp["ensembl_gene"], tmp["ensembl_effect_transcript"],tmp["ensembl_annovar_annotation"], tmp["ensembl_annotation"],
				#	      tmp["ensembl_gene_is_refgene_alias"], tmp["ensembl_transcript_is_refgene_transcript_alias"]
				#	     ].join(" ")
				#end
				
				annovars.each do |annovar_attrs|
					annovar_buffer << Annovar.new(annovar_attrs)
				end
				# annovar_buffer << annovars
				num_annotation += annovars.size
				if annovar_buffer.size > 1000 then
					SnupyAgain::DatabaseUtils.mass_insert(annovar_buffer.flatten)
					annovar_buffer = []
				end
			end
			
			if annovar_buffer.size > 0 then
				SnupyAgain::DatabaseUtils.mass_insert(annovar_buffer.flatten)
			end
			self.class.log_info "[ANNOVAR] added #{num_annotation} annotations for VcfFile##{vcf.id}..."
			archive_annovar_files result
			return true
		rescue => e
			self.class.log_fatal("#{e.message}: #{e.backtrace.join("=>")}")
			vcf.status = :ERROR
			vcf.save!
			raise
		end
		self.class.log_info("ANNOTATION DONE for VcfFile: #{vcf.name}. #annotations: #{num_annotation}")
		d "**************** store done *****************"
		return true
	end
	
	def store_invalid(file, organism_id)
		return nil unless File.exists?(file)
		fin = File.new(file, "r")
		annovar_buffer = []
		fin.each_line do |line|
			cols = line.strip.split("\t")
			variation_id = cols[-1]
			annovar_buffer << Annovar.new({
				variation_id: variation_id,
				organism_id: organism_id,
				ensembl_annovar_annotation: "invalid_input",
				ensembl_annotation: "sequence_variant",
				refgene_annovar_annotation: "invalid_input",
				refgene_annotation: "sequence_variant"
			})
		end
		fin.close
		SnupyAgain::DatabaseUtils.mass_insert(annovar_buffer.flatten)
		return annovar_buffer.flatten.size
	end
	
	def multi_key_entry(str)
		return {} if str.nil? or str.size == 0
		ret = str.to_s.split(";").map{|strx|
			strx.gsub("|", ",").split("=",2)
		}
		Hash[ret]
	end
	
	
	def map_hash_keys(src, map, &block)
		ret = Hash.new()
		map.each do |to, from|
			if from.is_a?(Proc) then
				if from.lambda?
					ret[to] = from.call(src)
				else
					ret[to] = lambda {|x| from.call(x)}.call(src)
				end
			else
				ret[to] = src[from]
			end
			
		end
		
		ret
	end
	
	def extract_transcript_consequences(rec, templates, prefix_record, prefix_annovarobj)
		ret = rec["Func.#{prefix_record}Gene"].each_with_index.map do |cons, considx|
			templates.map{|template|
				annotrec = template.dup
				annotrec["#{prefix_annovarobj}_annovar_annotation"]              = cons
				annotrec["#{prefix_annovarobj}_annotation"]                      = get_so_annotation(cons)
				annotrec["#{prefix_annovarobj}_gene"]                            = rec["Gene.#{prefix_record}Gene"][considx]
				if cons == "intergenic" then # extract distances
					if rec["GeneDetail.#{prefix_record}.ensGene"].is_a?(Array) then
						left_gene, left_dist   = rec["GeneDetail.#{prefix_record}Gene"][0].scan(/(.*)\(dist=(.*)\)/).flatten
						right_gene, right_dist = rec["GeneDetail.#{prefix_record}Gene"][1].scan(/(.*)\(dist=(.*)\)/).flatten
						left_gene = left_dist = nil if left_gene == "NONE"
						right_gene = right_dist = nil if right_dist == "NONE"
					else
						left_gene, left_dist, right_gene, right_dist = nil
					end
					annotrec["#{prefix_annovarobj}_left_gene_neighbor"] = left_gene
					annotrec["#{prefix_annovarobj}_distance_to_left_gene_neighbor"] = left_dist
					annotrec["#{prefix_annovarobj}_right_gene_neighbor"] = right_gene
					annotrec["#{prefix_annovarobj}_distance_to_right_gene_neighbor"] = right_dist
				elsif cons == "exonic"
					annotrec["#{prefix_annovarobj}_annotation"]                      = get_so_annotation(rec["ExonicFunc.#{prefix_record}Gene"][considx])
					if rec["AAChange.#{prefix_record}Gene"].size > 0 then
						annotrec = rec["AAChange.#{prefix_record}Gene"].map{|aastr|
							gene, transcript, exon, dna_change, protein_change, rest = aastr.split(":", 6)
							annot_rec_transcript = annotrec.dup
							annot_rec_transcript["#{prefix_annovarobj}_effect_transcript"] = transcript
							annot_rec_transcript["#{prefix_annovarobj}_region_sequence_change"] = exon
							annot_rec_transcript["#{prefix_annovarobj}_dna_sequence_change"] = dna_change
							annot_rec_transcript["#{prefix_annovarobj}_protein_sequence_change"] = protein_change
							annot_rec_transcript
						}
					else
						raise "ANNOVARANNOTATION(extract_transcript_consequences) consequnce is exonic, but no aminoacid change was given"
					end
				else
					if rec["GeneDetail.#{prefix_record}Gene"].size > 0 then
						annotrec = rec["GeneDetail.#{prefix_record}Gene"].map{|transcript_hgvs|
							transcript, hgvs = transcript_hgvs.split(":")
							annot_rec_transcript = annotrec.dup
							annot_rec_transcript["#{prefix_annovarobj}_effect_transcript"] = transcript
							annot_rec_transcript["#{prefix_annovarobj}_dna_sequence_change"] = hgvs
							annot_rec_transcript
						}
					end
				end
				annotrec
			}.flatten
		end
		ret.flatten
	end
	
	def get_so_annotation(func)
		if !@@ANNOVARSO[func].nil? then
			so_term = @@ANNOVARSO[func][:so_name]
		else
			so_term = ""
		end
		return so_term
	end
	
	def archive_annovar_files(result)
		self.class.log_info("ARCHIVING ANNOVAR annotation result: #{result}")
		success = system("tar --remove-files --no-recursion -czf '#{result}.tar.gz' #{result}.*")
		if !success then
			self.class.log_warning("ARCHIVING failed. PWD: #{Dir.getwd} Command: tar --remove-files --no-recursion -czf #{result}.tar.gz #{result}.*")
		end
	end
	
	# creates a hash table containing all gene identifiers and ensembl IDS used to find out if the affected transcripts in RefSeq and Ensembl are the same or not. 
	def build_ensembl_to_alias_lookup(organism_id)
		map = {}
		ActiveRecord::Base.connection.execute("SELECT * FROM annovar_ensembl2alias WHERE organism_id = #{organism_id}").each(as: :hash) do |row|
			map[row["ensembl_id"]] = {} if map[row["ensembl_id"]].nil?
			 map[row["ensembl_id"]][row["dbname"]] = [] if map[row["ensembl_id"]][row["dbname"]].nil?
			 map[row["ensembl_id"]][row["dbname"]] << row["alias"]
		end
		map
	end

end