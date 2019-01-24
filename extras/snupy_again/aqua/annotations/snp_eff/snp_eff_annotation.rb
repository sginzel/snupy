# == Description
# Performs an annotation using SnpEff.
# Genetic variant annotation and effect prediction toolbox.


class SnpEffAnnotationException < RuntimeError

end

class SnpEffAnnotation < Annotation
	
	register_tool name:      :snp_eff,
	              label:     'snpeff 4.1 db_75',
	              input:     :vcf,
	              output:    :vcf,
	              supports:  [:snp, :indel],
	              organism:  [organisms(:human), organisms(:mouse)],
	              model:     [SnpEff]
	
	@@SNPEFFEXECUTE = File.join(Rails.root, "tmp", "aqua_snp_eff_exec.sh")
	# @@SNPEFFERRORLOGER = Logger.new(File.join( Rails.root, "log", "snp_eff_annotation.error.log"),1,5242880)
	# @@SNPEFFLOGER = Logger.new(File.join( Rails.root, "log", "snp_eff_annotation.log"),1,5242880)
	
	# If the initilizer is overwritten a call to super is neccessary to setup the VCFHEADER variable to parse a Vcf file.
	def initialize(opts)
		super # neccessary to setup @VCFHEADER
		puts "I am born to be SnpEff!"
		## check setup snpeff file
		puts "SnpEffAnnotation: execute script path -> " + @@SNPEFFEXECUTE
		raise "SnpEffAnnotation: not ready to be executed. Did you execute bundle exec rake aqua:setup[snp_eff] ?" unless self.class.ready?
	end
	
	def self.ready?
		#return false if 1 == 1
		satisfied = super
		satisfied && File.exist?(@@SNPEFFEXECUTE)
	end
	
	# Load the configuration accoring to the Rails environment that we run under.
	def self.load_configuration_variable(field)
		configuration_file = File.join(Rails.root, "extras", "snupy_again", "aqua", "annotations", "snp_eff", "snp_eff.yaml")
		if !File.exists?(configuration_file) then
			raise "snp_eff.yaml - No such file or directory  "
		else
			conf = YAML.load(File.open(configuration_file).read)
			raise "Field #{field} not found in config file #{configuration_file} for environment #{Rails.env}" if conf[Rails.env][field].nil?
			template = conf[Rails.env][field]
			ret      = ERB.new(template.to_s).result(binding)
			return ret
		end
	end
	
	# Executes the actual annotation using SnpEff.
	# The SnpEff configuration is given by....
	# == SnpEff Options
	# [symbol] annotate with gene symbol
	# [,,,] ...
	def perform_annotation(file_path, input_vcf)
		puts "SnpEff WILL ANNOTATE: #{file_path}"
		puts "Organism: #{input_vcf.organism.id} - #{input_vcf.organism.name}"
		
		begin
			organism        = input_vcf.organism.name.to_s
			organism        = organism.downcase.gsub(" ", "_")
			output_vcf_file = File.join(Rails.root, "tmp", "#{File.basename(file_path, ".vcf")}.snpeff.vcf")
			if File.exists?(output_vcf_file) then
				File.rename(output_vcf_file, "#{output_vcf_file}.bak")
			end
			log_file       = File.join(Rails.root, "log", "annotation.log")
			error_log_file = File.join(Rails.root, "log", "annotation.error.log")
			self.class.log_info("SnpEff WILL ANNOTATE- ORGANISM: #{organism} INPUTVCF: #{file_path} OUTPUTVCF: #{output_vcf_file}")
			success = system("bash #{@@SNPEFFEXECUTE} -i \"#{file_path}\" -o \"#{output_vcf_file}\" -t #{organism} 2>#{error_log_file} 1>#{log_file}")
			self.class.log_info("SNPEff process success: #{success}")
			if !success then
				if File.exist?(error_log_file) then
					raise SnpEffAnnotationException.new("SnpEff Annotation Process Failed.(LOG: #{File.open(error_log_file, "r").read})")
				else
					raise SnpEffAnnotationException.new("SnpEff Annotation Process Failed for some unknown reason and without a log.")
				end
			end
		rescue => e
			self.class.log_fatal("#{e.message}: #{e.backtrace.join("\n")}")
			raise
		end
		puts "SNPEff Annotation done for #{input_vcf.id}"
		return output_vcf_file
	
	end
	
	# Maps each line of the SnpEff Vcf to a new database object.
	# Therefore the CSQ field of the INFO attribute needs to be parsed.
	# TODO: one annotation with two Ensembl Gene Ids - Lösung folgt
	# TODO: errors behandlung
	def store(result, vcf)
		num_annotation   = 0
		error_annotation = 0
		ann_values_rec   = {}
		begin
			fin = File.new(result, "r")
			
			snp_eff_buffer = []
			
			fin.each_line do |line|
				parse_vcf(line) {|rec|
					raise "Not annotated with SnpEff" if rec[:info]["ANN"].nil?
					snp_effs_to_write = {}
					#VID: Snupy variation id
					variation_id = rec[:info]["VID"]
					
					#LOF
					loss_of_function = rec[:info]["LOF"]
					if !loss_of_function.nil?
						lof_desc                            = @VCFHEADER["INFO"]["LOF"]["Description"]
						lof_desc                            = lof_desc.gsub(/[\']/, "")
						lof_desc_cols                       = lof_desc.scan(/Format: (.*)$/).flatten.first.split("|")
						loss_of_function                    = loss_of_function.gsub(/^[(]/, "").gsub(/[)]$/, "")
						lof_value_rec                       = loss_of_function.split("|", -1)
						lof_value_rec                       = Hash[lof_desc_cols.each_with_index.map {|col, i|
							val = lof_value_rec[i].to_s
							val = val[0] if val.size <= 1
							col = col.gsub(/[\s+]/, "")
							[col, val]
						}]
						lof_gene_name                       = lof_value_rec["Gene_Name"]
						lof_gene_id                         = lof_value_rec["Gene_ID"]
						lof_number_of_transcripts_in_gene   = lof_value_rec["Number_of_transcripts_in_gene"]
						lof_percent_of_transcripts_affected = lof_value_rec["Percent_of_transcripts_affected"].to_f
						lof_percent_of_transcripts_affected = lof_percent_of_transcripts_affected.to_f unless lof_percent_of_transcripts_affected.nil?
					end
					#NMD
					nonsense_mediated_decay = rec[:info]["NMD"]
					if !nonsense_mediated_decay.nil?
						nmd_desc                            = @VCFHEADER["INFO"]["NMD"]["Description"]
						nmd_desc                            = nmd_desc.gsub(/[\']/, "")
						nmd_desc_cols                       = nmd_desc.scan(/Format: (.*)$/).flatten.first.split("|")
						nonsense_mediated_decay             = nonsense_mediated_decay.gsub(/^[(]/, "").gsub(/[)]$/, "")
						nmd_value_rec                       = nonsense_mediated_decay.split("|", -1)
						nmd_value_rec                       = Hash[nmd_desc_cols.each_with_index.map {|col, i|
							val = nmd_value_rec[i].to_s
							val = val[0] if val.size <= 1
							col = col.gsub(/[\s+]/, "")
							[col, val]
						}]
						nmd_gene_name                       = nmd_value_rec["Gene_Name"]
						nmd_gene_id                         = nmd_value_rec["Gene_ID"]
						nmd_number_of_transcripts_in_gene   = nmd_value_rec["Number_of_transcripts_in_gene"]
						nmd_percent_of_transcripts_affected = nmd_value_rec["Percent_of_transcripts_affected"]
						nmd_percent_of_transcripts_affected = nmd_percent_of_transcripts_affected.to_f unless nmd_percent_of_transcripts_affected.nil?
					end
					
					#ANN
					annotations                = rec[:info]["ANN"]
					annotations_multiple_genes = rec[:info]["ANN"].split(",", -1)
					ann_desc                   = @VCFHEADER["INFO"]["ANN"]["Description"]
					ann_desc                   = ann_desc.gsub(/[\']/, "")
					ann_desc_cols              = ann_desc.scan(/Functional annotations: (.*)$/).flatten.first.split("|")
					
					annotations_multiple_genes.each do |ann|
						ann_values_rec = ann.split("|", -1)
						ann_values_rec = Hash[ann_desc_cols.each_with_index.map {|col, i|
							val = ann_values_rec[i].to_s
							val = val[0] if val.size <= 1
							col = col.gsub(/[\s+]/, "")
							[col, val]
						}]
						#SnpEff Errors and Warnings Handling
						errors         = ann_values_rec["ERRORS/WARNINGS/INFO"] unless ann_values_rec["ERRORS/WARNINGS/INFO"].nil?
						if !errors.nil? then
							errors.split("\\", -1) unless errors.nil?
							if errors.is_a?(Array) then
								errors.each {|error|
									result = snp_eff_handling(variation_id, error)
									(error_annotation += 1) if result
									next if result
								}
							else
								result = snp_eff_handling(variation_id, errors)
								(error_annotation += 1) if result
								next if result
							end
						end
						annotations       = ann_values_rec["Annotation"].split("&", -1) unless ann_values_rec["Annotation"].nil?
						annotation_impact = ann_values_rec["Annotation_Impact"]
						
						symbol           = ann_values_rec["Gene_Name"]
						ensembl_gene_id  = ann_values_rec["Gene_ID"]
						ensembl_gene_ids = ann_values_rec["Gene_ID"].split("-", -1) unless ann_values_rec["Gene_ID"].nil?
						ensembl_gene_id  = ensembl_gene_ids[0] unless ensembl_gene_ids.nil?
						
						ensembl_feature_type = ann_values_rec["Feature_Type"]
						ensembl_feature_id   = ann_values_rec["Feature_ID"]
						ensembl_feature_ids  = ann_values_rec["Feature_ID"].split("-", -1) unless ann_values_rec["Feature_ID"].nil?
						ensembl_feature_id   = ensembl_feature_ids[0] unless ensembl_feature_ids.nil?
						
						transcript_biotype = ann_values_rec["Transcript_BioType"]
						hgvs_c             = ann_values_rec["HGVS.c"]
						hgvs_p             = ann_values_rec["HGVS.p"]
						cdna               = ann_values_rec["cDNA.pos/cDNA.length"].split("\\", -1) unless ann_values_rec["cDNA.pos/cDNA.length"].nil?
						cdna_pos           = cdna[0] unless cdna.nil?
						cdna_length        = cdna[1] unless cdna.nil?
						cds                = ann_values_rec["CDS.pos/CDS.length"].split("\\", -1) unless ann_values_rec["CDS.pos/CDS.length"].nil?
						cds_pos            = cds[0] unless cds.nil?
						cds_length         = cds[1] unless cds.nil?
						aa                 = ann_values_rec["AA.pos/AA.length"].split("\\", -1) unless ann_values_rec["AA.pos/AA.length"].nil?
						aa_pos             = aa[0] unless aa.nil?
						aa_length          = aa[1] unless aa.nil?
						distance           = ann_values_rec["Distance"]
						
						#effects
						annotations.each {|annot|
							annotation               = annot
							attrs                    = {
								variation_id:                        variation_id,
								organism_id:                         vcf.organism.id,
								annotation:                          annotation,
								annotation_impact:                   annotation_impact,
								symbol:                              symbol,
								ensembl_gene_id:                     ensembl_gene_id,
								ensembl_feature_type:                ensembl_feature_type,
								ensembl_feature_id:                  ensembl_feature_id,
								transcript_biotype:                  transcript_biotype,
								hgvs_c:                              hgvs_c,
								hgvs_p:                              hgvs_p,
								cdna_pos:                            cdna_pos,
								cdna_length:                         cdna_length,
								cds_pos:                             cds_pos,
								cds_length:                          cds_length,
								aa_pos:                              aa_pos,
								aa_length:                           aa_length,
								distance:                            distance,
								lof_gene_name:                       lof_gene_name,
								lof_gene_id:                         lof_gene_id,
								lof_number_of_transcripts_in_gene:   lof_number_of_transcripts_in_gene,
								lof_percent_of_transcripts_affected: lof_percent_of_transcripts_affected,
								nmd_gene_name:                       nmd_gene_name,
								nmd_gene_id:                         nmd_gene_id,
								nmd_number_of_transcripts_in_gene:   nmd_number_of_transcripts_in_gene,
								nmd_percent_of_transcripts_affected: nmd_percent_of_transcripts_affected
							}
							snp_effs_to_write[attrs] = SnpEff.new(attrs) if snp_effs_to_write[attrs].nil?
						}
					end # end of annotation_multiple_genes
					snp_eff_buffer += snp_effs_to_write.values
					num_annotation += snp_effs_to_write.size
					if snp_eff_buffer.size > 1000 then
						SnupyAgain::DatabaseUtils.mass_insert(snp_eff_buffer)
						snp_eff_buffer = []
					end
				} #end parse_line
			end #end each_line
			if snp_eff_buffer.size > 0 then
				SnupyAgain::DatabaseUtils.mass_insert(snp_eff_buffer)
			end
			self.class.log_info("ANNOTATION  DONE for VcfFile: #{vcf.name}. #annotations: #{num_annotation} #error_annotations: #{error_annotation}")
			return true
		rescue => e
			self.class.log_fatal("#{e.message}: #{e.backtrace.join("\n")}")
			vcf.status = :ERROR
			vcf.save!
			raise
		end
		return true
	end
	
	def snp_eff_handling(variation_id, error)
		self.class.log_error("SnpEff error by variation_id #{variation_id}: #{error}") if error == ("ERROR_CHROMOSOME_NOT_FOUND")
		self.class.log_error("SnpEff error by variation_id #{variation_id}: #{error}") if error == ("ERROR_OUT_OF_CHROMOSOME_RANGE")
		#self.class.log_warn("SnpEff WARNING by variation_id #{variation_id}: #{error}") if error == ("WARNING_REF_DOES_NOT_MATCH_GENOME")
		#self.class.log_warn("SnpEff WARNING by variation_id #{variation_id}: #{error}") if error == ("WARNING_SEQUENCE_NOT_AVAILABLE")
		#self.class.log_warn("SnpEff WARNING by variation_id #{variation_id}: #{error}") if error == ("WARNING_TRANSCRIPT_INCOMPLETE")
		#self.class.log_warn("SnpEff WARNING by variation_id #{variation_id}: #{error}") if error == ("WARNING_TRANSCRIPT_MULTIPLE_STOP_CODONS")
		#self.class.log_warn("SnpEff WARNING by variation_id #{variation_id}: #{error}") if error == ("WARNING_TRANSCRIPT_NO_START_CODON")
		result = (error == "ERROR_CHROMOSOME_NOT_FOUND") || (error == "ERROR_OUT_OF_CHROMOSOME_RANGE") || (error == "WARNING_REF_DOES_NOT_MATCH_GENOME")
		return result
	
	end

end