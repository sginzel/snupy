# == Description
# Performs an annotation using Variant Effect Predictor by Ensembl.

class VariantEffectPredictorException < RuntimeError

end


class VariantEffectPredictorAnnotation < Annotation
	
	# register tool is on bottom of class declaration.
	
	# @@VEPERRORLOGER = Logger.new(File.join( Rails.root, "log", "vep_annotation.error.log"),1,5242880)
	# @@VEPLOGER = Logger.new(File.join( Rails.root, "log", "vep_annotation.log"),1,5242880)
	# @@VEPERRORLOGER = @@VEPLOGER 
	
	def self.test_annot()
		# vcf = VcfFile.find(118)
		# ap = AquaAnnotationProcess.new(118, [AnnovarAnnotation, SnpEffAnnotation, VariantEffectPredictorAnnotation] )
		ap = AquaAnnotationProcess.new(61)
		ap.start([VariantEffectPredictorAnnotation])
		vepa = VariantEffectPredictorAnnotation.new({})
	end
	
	# If the initilizer is overwritten a call to super is neccessary to setup the VCFHEADER variable to parse a Vcf file. 
	def initialize(opts = {})
		super # neccessary to setup @VCFHEADER
		d "I am born to be VEP!"
		## check setup vep file
		raise "VariantEffectPredictorpAnnotation: execute script dont exist, plesase run bundle exec rake aqua:setup[variant_effect_predictor]"  unless self.class.ready?
		puts "VariantEffectPredictorpAnnotation: execute script path -> "+ VariantEffectPredictorAnnotation.get_executable
		self.class.log_info("VEP initialized: #{VariantEffectPredictorAnnotation.get_executable}")
	end
	
	def self.get_executable
		ensversion = VariantEffectPredictorAnnotation.load_configuration_variable("ensembl_version")
		hsbuild = VariantEffectPredictorAnnotation.load_configuration_variable("homo_sapiens_build")
		mmbuild = VariantEffectPredictorAnnotation.load_configuration_variable("mus_musculus_build")
		@@VEPEXECUTE = File.join(Rails.root, "tmp", "aqua_vep_exec_#{ensversion}_hs#{hsbuild}_mm#{mmbuild}.sh")
		@@VEPEXECUTE
	end
	
	def self.ready?
		ready = super
		ready && File.exist?(VariantEffectPredictorAnnotation.get_executable)
		false
	end

	# Load the configuration accoring to the Rails environment that we run under.
	def self.load_configuration_variable(field)
		configuration_file = File.join(Rails.root, "extras", "snupy_again", "aqua", "annotations" ,"variant_effect_predictor", "variant_effect_predictor.yaml")
		if !File.exists?(configuration_file) then
			raise "variant_effect_predictor.yaml - No such file or directory  "
		else
			conf = YAML.load(File.open(configuration_file).read)
			raise "Field #{field} not found in config file #{configuration_file} for environment #{Rails.env}" if conf[Rails.env][field].nil?
			template = conf[Rails.env][field]
			ret = ERB.new(template.to_s).result(binding)
			return ret
		end
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
			output_vcf_file = File.join(Rails.root, "tmp", "#{File.basename(file_path,".vcf")}.vep.vcf")
			d "VEP OUTPUT: #{output_vcf_file}"
			if File.exists?(output_vcf_file) then
				File.rename(output_vcf_file, "#{output_vcf_file}.bak")
			end
			log_file = File.join(Rails.root, "log", "vep_annotation.log")
			error_log_file = File.join(Rails.root, "log", "vep_annotation.error.log")
			if Rails.env == "development" then
				success = system("bash #{VariantEffectPredictorAnnotation.get_executable} -d -i \"#{file_path}\" -o \"#{output_vcf_file}\" -t \"#{species.downcase.gsub(" ", "_")}\" 2>#{error_log_file} 1>#{log_file}")
			else
				success = system("bash #{VariantEffectPredictorAnnotation.get_executable} -i \"#{file_path}\" -o \"#{output_vcf_file}\" -t \"#{species.downcase.gsub(" ", "_")}\" 2>#{error_log_file} 1>#{log_file}")
			end
			self.class.log_info("VEP process succesfull?: #{success}")
			if !success then
				if File.exist?(error_log_file) then
					raise VariantEffectPredictorException.new("Annotation Process Failed.(LOG: #{File.open(error_log_file, "r").read})")
				else
					raise VariantEffectPredictorException.new("Annotation Process Failed for some unknown reason and without a log.")
				end
			else # check if the output file exists - because if the input file didnt have and variations there is no output file but there should be
				if (!File.exists?(output_vcf_file)) then
					self.class.log_info "VEP Output (#{output_vcf_file}) does not exist, but process was successfull. Maybe the INPUT is empty - creating empty output file"
					FileUtils.touch(output_vcf_file)
				end
			end
			
		rescue => e
			self.class.log_fatal("#{e.message}: #{e.backtrace.pretty_print_inspect}")
			raise
		end
		return output_vcf_file
	end
		# Maps each line of the VEP Vcf to a new database object.
	# Therefore the CSQ field of the INFO attribute needs to be parsed. 
	def store(result, vcf)
		begin
			organism_id = vcf.organism.id
			veprec = {}
			fin = File.new(result, "r")
			
			store_begin = Time.now
			last_variation_annotation_id_before_update = VariationAnnotation.maximum(:id)
			# required for initial insert
			last_variation_annotation_id_before_update = 0 if last_variation_annotation_id_before_update.nil?
			
			d "adding genetic elements..."
			time_begin = Time.now
			ge_map = add_genetic_elements(fin, vcf.organism.id)
			d "#GeneticElements: #{ge_map.size} in #{Time.now-time_begin} sec."
			d "adding consequences..."
			cons_map = add_consequences(fin)
			d "adding LOFP objects..."
			lof_map = add_loss_of_functions(fin)
			
			d "adding VEP Annotations..."
			time_begin = Time.now
			# SnupyAgain::Profiler.profile("add_vep_annot") {
			num_vep_annot = add_vep_annotations(fin, ge_map, lof_map, organism_id)
			d "#VEP Annotations: #{num_vep_annot} in #{Time.now-time_begin} sec."
			# } # end of profiling
			
			d "adding consequences for VEP Annotations..."
			time_begin = Time.now
			add_vep_annotation_consequences(fin, ge_map, lof_map, cons_map, organism_id)
			d "Consequences: #{Time.now-time_begin} sec."
			d "Storing took #{Time.now-store_begin} sec."
			self.class.log_info("ANNOTATIONSTORE  DONE for VcfFile: #{vcf.name}. #annotations: #{num_vep_annot}")
			num_no_consequence = VariationAnnotation.where("id > #{last_variation_annotation_id_before_update}")
																							.where(has_consequence: false)
																							.count
			
			if num_no_consequence > 0 then
				raise "#{num_consequence} annotations have not been asigned a consequence."
			end
			num_new_annotations = VariationAnnotation.where("id > #{last_variation_annotation_id_before_update}").count
			if num_new_annotations != num_vep_annot then
				raise "we wanted to add #{num_vep_annot}, but only #{num_new_annotations} made it to the database. Last valid VariationAnnotationID: #{last_variation_annotation_id_before_update}"
			end
			self.class.log_info("VEP-ANNOTATION  DONE for VcfFile: #{vcf.name}. #annotations: #{num_vep_annot}")
			d "Done Storing VEP Annotations..."
			return true
		rescue => e
			# Erase all annotations that made it to the database
			no_consequence_ids = VariationAnnotation.where(has_consequence: false).pluck(:id)
			no_consequence_ids.each_slice(1000) do |idchunk|
				ActiveRecord::Base.connection.execute("DELETE FROM variation_annotation_has_consequence WHERE variation_annotation_id IN (#{idchunk.join(",")})")
			end
			num_deleted = VariationAnnotation.where(has_consequence: false).delete_all
			self.class.log_fatal("ERROR DURING VEP store (removed #{num_deleted} wrong entries)#{e.message}: #{e.backtrace.join("\n")}")
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
	
	def add_genetic_elements(fin, organism_id, buffersize = 1100)
		add_vep_fields_to_model(fin,
														{
															"Gene" => :ensembl_gene_id,
															"Feature" => :ensembl_feature_id,
															"Feature_type" => :ensembl_feature_type,
															"HGNC" => :hgnc,
															"SYMBOL" => :hgnc,
															"ENSP" => :ensp
														}, 
														GeneticElement, 
														organism_id = organism_id, 
														buffersize = buffersize)
	end
	
	def add_consequences(fin)
		cons_map = Hash[Consequence.all.map{|cons| [cons.consequence, cons] }]
		vepcols = nil
		fin.seek(0) # make sure we start from the first line.
		fin.each_line do |line|
			parse_vcf(line) do |rec|
				raise "Not annotated with VEP" if rec[:info]["CSQ"].nil?
				if vepcols.nil? then
					vepcols = get_vep_columns()
				end
				rec[:info]["CSQ"].split(",").each do |vepline|
					veprec = get_vep_record(vepline, vepcols)
					consequences = veprec["Consequence"]
					consequences = [consequences] unless consequences.is_a?(Array)
					consequences.each do |cons|
						if cons_map[cons].nil? then
							consobj = Consequence.new(consequence: cons)
							consobj.save!
							cons_map[cons] = consobj
						end
					end
				end # end of split
			end # end of parse_vcf
		end # end of each_line
		cons_map
	end
	
	def parse_lof(str) 
		str.scan(/^(.*)\(/).flatten.first
	end
	 
	def add_loss_of_functions(fin)
		lof_map = Hash[LossOfFunction.all.map{|lof| 
			[{sift: lof.sift, polyphen: lof.polyphen, condel: lof.condel}, lof] 
		}]
		vepcols = nil
		fin.seek(0) # make sure we start from the first line.
		fin.each_line do |line|
			parse_vcf(line) do |rec|
				raise "Not annotated with VEP" if rec[:info]["CSQ"].nil?
				if vepcols.nil? then
					vepcols = get_vep_columns()
				end
				rec[:info]["CSQ"].split(",").each do |vepline|
					veprec = get_vep_record(vepline, vepcols)
					sift = parse_lof(veprec["SIFT"].to_s)
					polyphen = parse_lof(veprec["PolyPhen"].to_s)
					condel = parse_lof(veprec["Condel"].to_s) 
					lofrec = {sift: sift, polyphen: polyphen, condel: condel}
					if lof_map[lofrec].nil? then
						lofobj = LossOfFunction.new(lofrec)
						lofobj.save!
						lof_map[lofrec] = lofobj
					end
				end # end of split
			end # end of parse_vcf
		end # end of each_line
		lof_map
	end
	
	def add_vep_annotations(fin, ge_map, lof_map, organism_id)
		fin.seek(0)
		num_annotation = 0
		vepcols = nil
		write_buffer = []
		
		fin.each_line do |line|
			parse_vcf(line) do |rec|
				raise "Not annotated with VEP" if rec[:info]["CSQ"].nil?
				if vepcols.nil? then
					vepcols = get_vep_columns()
				end
				variation_id = rec[:info]["VID"]
				annot_map = {}
				rec[:info]["CSQ"].split(",").each do |vepline|
					
					veprec = get_vep_record(vepline, vepcols)
					
					annot_attr = get_annot_attr_from_veprec(veprec, ge_map, lof_map, variation_id, organism_id)
					
					vep_annot = generate_variation_annotation(veprec, variation_id, organism_id)
					# vep_annot.consequences = [veprec["Consequence"]].flatten.map{|cons| cons_map[cons]}
					
					# vep_annot.genetic_element_id = annot_attr[:genetic_element_id]
					# vep_annot.loss_of_function_id = annot_attr[:loss_of_function_id]
					vep_annot[:genetic_element_id] = annot_attr[:genetic_element_id]
					vep_annot[:loss_of_function_id] = annot_attr[:loss_of_function_id]
					
					if not annot_map[annot_attr].nil?
						if veprec["Feature_type"] != "MotifFeature" then
							self.class.log_fatal("[VEP-ERROR] key for annotation mapping is not unique")
							self.class.log_fatal("[VEP-ERROR] --> VEPLINE: #{vepline}")
							self.class.log_fatal("[VEP-ERROR] --> annot_attr: #{annot_attr}")
							raise "Key for annotation mapping is not unique"
						else
							self.class.log_info("[VEP-INFO] key for annotation mapping is not unique. This happpens when a variant hits a motif on both strands. Only the first variant of this kind is stored then.")
							self.class.log_info("[VEP-INFO] --> VEPLINE: #{vepline}")
							self.class.log_info("[VEP-INFO] --> annot_attr: #{annot_attr}")
							next
						end
					end 
					annot_map[annot_attr] = vep_annot
					
					write_buffer << vep_annot
					num_annotation += 1
					
					print("#{num_annotation} records...\r")
					if write_buffer.size > 1100 
						SnupyAgain::DatabaseUtils.mass_insert(write_buffer, false, 10000, VariationAnnotation)
						write_buffer = []
					end
				end # end of line.split
			end # end of parse_vcf
		end # end of each_line
		
		if write_buffer.size > 0
			SnupyAgain::DatabaseUtils.mass_insert(write_buffer, false, 10000, VariationAnnotation)
		end # end of empty buffer
		print("#{num_annotation} records...DONE\n")
		num_annotation
	end
	
	def add_vep_annotation_consequences(fin, ge_map, lof_map, cons_map, organism_id, from_variation_annotation_id = 0)
		num_annotation = 0
		vepcols = nil
		write_buffer = {}
		# from_variation_annotation_id
		va_without_consequences = _create_query_buffer(VariationAnnotation, [:variation_id, :genetic_element_id, :loss_of_function_id, :organism_id, :motif_pos], organism_id, {conditions: ["id > ? AND has_consequence = 0", from_variation_annotation_id]}, false)
		self.class.log_warning("No variation annotation without consequence found in database. This is unusual...") if va_without_consequences.size == 0
		# pp va_without_consequences
		# pp "-------"
		# pp va_without_consequences.keys.first
		# p "+++++++"
		# pp va_without_consequences[va_without_consequences.keys.first]
		fin.seek(0)
		fin.each_line do |line|
			parse_vcf(line) do |rec|
				raise "Not annotated with VEP" if rec[:info]["CSQ"].nil?
				if vepcols.nil? then
					vepcols = get_vep_columns()
				end
				variation_id = rec[:info]["VID"]
				rec[:info]["CSQ"].split(",").each do |vepline|
					veprec = get_vep_record(vepline, vepcols)
					annot_attr = get_annot_attr_from_veprec(veprec, ge_map, lof_map, variation_id, organism_id)
					cons_ids = [veprec["Consequence"]].flatten.map{|cons| cons_map[cons]}
					key = {:variation_id => annot_attr[:variation_id].to_i, 
								 :genetic_element_id => annot_attr[:genetic_element_id].to_i, 
								 :loss_of_function_id => annot_attr[:loss_of_function_id].to_i, 
								 :organism_id => annot_attr[:organism_id].to_i, 
								 :motif_pos => (annot_attr[:motif_pos].nil?)?annot_attr[:motif_pos]:annot_attr[:motif_pos].to_i #(annot_attr[:motif_pos].nil?)?(""):(annot_attr[:motif_pos])
								 }
					annotids = (va_without_consequences[key] || [])
					raise "annotation #{key} attribute is not uniq. Cannot set consequences..." if annotids.size > 1
					raise "annotation #{key} was not found. Cannot set consequences... (#{va_without_consequences.keys.first})" if annotids.size == 0
					write_buffer[annotids.first] = cons_ids
					# write_buffer[annot_attr] = cons_ids
					if (write_buffer.size > 1100)
						write_consequences(write_buffer)
						write_buffer = {}
					end
				end # end of line.split
			end # end of vcf_parse
		end# end of each line
		if (write_buffer.size > 0)
			write_consequences(write_buffer)
			write_buffer = {}
		end
	end
	
	def generate_variation_annotation(veprec, variation_id, organism_id)
		global_pop_freq = []
		[veprec["GMAF"]].flatten.each do |gmaf|
			allele, freq = gmaf.to_s.split(":")
			if !freq.nil?
				if (allele == veprec["Allele"])
					global_pop_freq << freq.to_f
				else
					global_pop_freq << (1 - freq.to_f).round(4)
				end
			end
		end
		global_pop_freq = global_pop_freq.min # is nil if array is empty
		
		# creating the object and then iterating over the hash to set its attributes
		# is about 15% faster than initing an object with a hash (Rails 2.3.8)
		# vep_annot = VariationAnnotation.new()
		vep_annot = {
			:cdna_position => veprec["cDNA_position"],
			:cds_position => veprec["CDS_position"],
			:protein_position => veprec["Protein_position"],
			:amino_acids => veprec["Amino_acids"],
			:codons => veprec["Codons"],
			:existing_variation => veprec["Existing_variation"],
			:exon => veprec["EXON"],
			:intron => veprec["INTRON"],
			:motif_name => veprec["MOTIF_NAME"],
			:motif_pos => veprec["MOTIF_POS"],
			:high_inf_pos => veprec["HIGH_INF_POS"] == "Y",
			:motif_score_change => veprec["MOTIF_SCORE_CHANGE"],
			:sv => nil, #veprec[""], # we discard the structural variations...
			:distance => veprec["DISTANCE"],
			:canonical => veprec["CANONICAL"],
			:sift_score => ((veprec["SIFT"] || "").scan(/\((.*)\)/).flatten.first || 1).to_f,
			:polyphen_score => ((veprec["PolyPhen"] || "").scan(/\((.*)\)/).flatten.first || 1).to_f, 
			:gmaf => veprec["GMAF"],
			:domains => veprec["DOMAINS"],
			:ccds => veprec["CCDS"],
			:hgvsc => veprec["HGVSc"],
			:hgvsp => veprec["HGVSp"],
			:blosum62 => veprec["BLOSUM62"],
			:other_yaml => nil,
			:global_pop_freq => global_pop_freq,
			:has_consequence => 0,
			:variation_id => variation_id,
			:organism_id => organism_id
		}
		#.each do |k,v|
		#	vep_annot.send("#{k}=", v)
		#end
		vep_annot
	end
	
	def get_ge_attr_from_veprec(veprec, organism_id)
		ge_attr = {
			ensembl_gene_id: veprec["Gene"],
			ensembl_feature_id: veprec["Feature"],
			ensembl_feature_type: veprec["Feature_type"],
			hgnc: (veprec["HGNC"] || veprec["SYMBOL"]),
			ensp: veprec["ENSP"],
			"organism_id" => organism_id
		}
		ge_attr
	end
	
	def get_lof_attr_from_veprec(veprec)
		{
			sift: parse_lof(veprec["SIFT"].to_s),
			polyphen: parse_lof(veprec["PolyPhen"].to_s),
			condel: parse_lof(veprec["Condel"].to_s)
		}
	end
	
	def get_annot_attr_from_veprec(veprec, ge_map, lof_map, variation_id, organism_id)
		ge_attr = get_ge_attr_from_veprec(veprec, organism_id)
		lof_attr = get_lof_attr_from_veprec(veprec)
		raise "Genetic Element not found" if ge_map[ge_attr].nil?
		raise "LossOfFunction not found" if lof_map[lof_attr].nil?
		
		genetic_element_id = ge_map[ge_attr].id
		loss_of_function_id = lof_map[lof_attr].id
		
		{
			variation_id: variation_id, 
			organism_id: organism_id, 
			genetic_element_id: genetic_element_id,
			loss_of_function_id: loss_of_function_id,
			motif_pos: veprec["MOTIF_POS"]
		}
		
	end
	
	def write_consequences(annot2consids)
		annot2cons = []
		annotids = []
		
		annot2consids.each do |annot_id, consids|
			annotids << annot_id
			consids.each do |consid|
				annot2cons << [annot_id, consid]
			end
		end
		# insert them into the relation table
		SnupyAgain::DatabaseUtils.sql_mass_insert("variation_annotation_has_consequence", [:variation_annotation_id, :consequence_id], annot2cons)
		# set the has_consequence flag
		VariationAnnotation.where(id: annotids).update_all(has_consequence: true)
		true
	end
	
	def write_consequences_old(annot2consids)
		annot2cons = []
		annotids = []
		# determine the variation_annotation_id for the given annotation objects
		SnupyAgain::DatabaseUtils
		.batch_query(annot2consids.keys, VariationAnnotation,[:id, :variation_id, :genetic_element_id, :loss_of_function_id, :organism_id, :motif_pos])
		.each do |annot_rec|
			annotids << annot_rec[:id]
			annot_attr = {
				variation_id: 				annot_rec[:variation_id].to_s, 
				organism_id: 					annot_rec[:organism_id], 
				genetic_element_id: 	annot_rec[:genetic_element_id],
				loss_of_function_id: 	annot_rec[:loss_of_function_id],
				motif_pos: 						annot_rec[:motif_pos]
			}
			annot_attr[:motif_pos] = annot_attr[:motif_pos].to_s unless annot_rec[:motif_pos].nil?
			consids = annot2consids[annot_attr]
			if consids.nil? then
				raise "No consequences found for #{annot_attr}"
			end
			 
			annot_id = annot_rec[:id]
			consids.each do |consid|
				annot2cons << [annot_id, consid]
			end
		end # end of batch query
		
		# insert them into the relation table
		SnupyAgain::DatabaseUtils.sql_mass_insert("variation_annotation_has_consequence", [:variation_annotation_id, :consequence_id], annot2cons)
		# set the has_consequence flag
		VariationAnnotation.where(id: annotids).update_all(has_consequence: true)
		# reset buffer
	end
	
	# fin: File object of an annotated vcf
	# vep_attr_to_model_attr: Hash to map vep attributes to model attributes
	#       {Gene: ensembl_gene_id, ENSP: ensp, ...}
	# model: Model to use for insert and query statements
	# organism_id: valid organism id or nil
	# buffersize: buffer size used for queries and inserts
	# Description: The vep_attr_to_model_attr Hash is used to map vep attributes to 
	# model attributes. If the model contains organism_id or variation_id columns
	# then the organism_id parameter and the VID field are used
	def add_vep_fields_to_model(fin, vep_attr_to_model_attr, model, organism_id = nil, buffersize = 1100, &block)
		observed_objects = {}
		query_buffer = {}
		write_buffer = {}
		
		vepcols = nil
		
		variation_id_required = model.attribute_names.include?("variation_id")
		organism_id_required = model.attribute_names.include?("organism_id")
		
		raise "organism_id is missing" if organism_id_required and organism_id.nil?
		
		vep_attributes = vep_attr_to_model_attr.keys
		model_attributes = vep_attr_to_model_attr.values.flatten
		model_attributes += ["organism_id"] if organism_id_required
		model_attributes += ["variation_id"] if variation_id_required
		query_buffer = _create_query_buffer(model, model_attributes, organism_id, {})
		
		fin.seek(0) # make sure we are at the beginning of the file
		fin.each_line do |line|
			parse_vcf(line) do |rec|
				raise "Not annotated with VEP" if rec[:info]["CSQ"].nil?
				if vepcols.nil? then
					vepcols = get_vep_columns()
				end
				variation_id = rec[:info]["VID"]
				rec[:info]["CSQ"].split(",").each do |vepline|
					veprec = get_vep_record(vepline, vepcols)
					# built record
					modelrec = {}
					modelrec["variation_id"] = variation_id if variation_id_required
					modelrec["organism_id"] = organism_id if organism_id_required
					vep_attr_to_model_attr.each do |vepattr, modattr|
						modelrec[modattr] = veprec[vepattr] unless (!modelrec[modattr].nil?) and veprec[vepattr].nil?
					end
					if query_buffer[modelrec].nil? then
						if write_buffer[modelrec].nil? then # if the object is not to be added to the database already..
							write_buffer[modelrec] = model.new(modelrec)
						end
					end
					
					## check for write buffer overflow
					if write_buffer.size > buffersize then
						empty_write_buffer(write_buffer, query_buffer, model_attributes)
						write_buffer = {}
					end
					next
					
					query_buffer[modelrec] = modelrec
					## check for query buffer overflow
					if query_buffer.size > buffersize then
						empty_query_buffer(query_buffer, write_buffer, observed_objects, model, vep_attr_to_model_attr)
						query_buffer = {}
					end # end of query_buffer handling
				end # end of line[CSQ].split
			end # end of parse_vcf.each
		end # end of each_line
		
		# empty write buffer
		## check for write buffer overflow
		if write_buffer.size > 0 then
			empty_write_buffer(write_buffer, query_buffer, model_attributes)
			write_buffer = {}
		end # end of empty write buffer
		
		# retrieve all objects from the datbase...although this might be a lot...
		observed_objects = _create_query_buffer(model, model_attributes, organism_id, {}, true)
		
		
		return observed_objects if 1 == 1
		
		# empty query buffer
		if query_buffer.size > 0 then
			empty_query_buffer(query_buffer, write_buffer, observed_objects, model, vep_attr_to_model_attr)
			
			## If the buffer size is greater than the number of elements in the file then
			## the query_buffer is not empty and the write buffer was not populated yet
			if query_buffer.size > 0
				if write_buffer.size > 0
					empty_write_buffer(write_buffer, query_buffer)
					empty_query_buffer(query_buffer, write_buffer, observed_objects, model, vep_attr_to_model_attr)
				end
			end
			if query_buffer.size > 0
				raise "[#{model.name}] #{query_buffer.size} Objects were supposed to be added to the database, but were not found."
			end
		end # end of empty query buffer
		
		return observed_objects
	end
	
	# this method queries all instances of a model and creates a hash map of its attributes to 
	# the IDs that carry the attribute 
	def _create_query_buffer(model, attributes, organism_id, opts = {}, return_model = false)
		query_buffer = {}
		# model.select(([:id] + attributes).uniq).find_each(opts) do |ge|
		if organism_id.nil? then
			organism_id = Organism.pluck(:id)
		end
		model.where(organism_id: organism_id).find_each({batch_size: 1100}.merge(opts)) do |ge|
			key = Hash[attributes.map{|a| [a, ge[a]]}]
			if !return_model
				query_buffer[key] = [] if query_buffer[key].nil?
				query_buffer[key] << ge.id
			else
				if query_buffer[key].nil? then
					query_buffer[key] = ge
				else
					query_buffer[key] = [query_buffer[key]] unless query_buffer[key].is_a?(Array)
					query_buffer[key] << ge
				end 
			end
		end
		query_buffer
	end
	
	def empty_query_buffer(query_buffer, write_buffer, observed_objects, model, vep_attr_to_model_attr)
		existing_objects = SnupyAgain::DatabaseUtils.batch_query(query_buffer.values.flatten, model)
		variation_id_required = model.attribute_names.include?("variation_id")
		organism_id_required = model.attribute_names.include?("organism_id")
		## add  existing genetic element to lookup and remove them the query buffer
		existing_objects.each do |obj|
			modelrec = {}
			modelrec["variation_id"] = obj.variation_id if variation_id_required
			modelrec["organism_id"] = obj.organism_id if organism_id_required
			vep_attr_to_model_attr.each do |vepattr, modattr|
				modelrec[modattr] = obj[modattr]
			end
			query_buffer.delete(modelrec)
			observed_objects[modelrec] = obj
		end
		
		## add missing genetic elements to write buffer
		if query_buffer.size > 0 then
			query_buffer.each do |obj_attrs, obj_attrs1|
				write_buffer[obj_attrs] = model.new(obj_attrs)
			end
		end
	end
	
	def empty_write_buffer(write_buffer, query_buffer, attributes_for_existance)
		SnupyAgain::DatabaseUtils.mass_insert(write_buffer.values.flatten)
		## add the genetic elements that were just written to the query buffer
		write_buffer.each do |obj_attrs, obj|
			key = Hash[attributes_for_existance.map{|a| [a, obj_attrs[a]]}]
			query_buffer[key] = [-1] # add a invalid id
		end
	end
	
	def empty_write_buffer_to_delete(write_buffer, query_buffer)
		SnupyAgain::DatabaseUtils.mass_insert(write_buffer.values.flatten)
		## add the genetic elements that were just written to the query buffer
		write_buffer.each do |obj_attrs, obj|
			query_buffer[obj_attrs] = obj_attrs
		end
	end
	
	register_tool name: :variant_effect_predictor,
								label: "Variant Effect Predictor #{VariantEffectPredictorAnnotation.load_configuration_variable("ensembl_version")}", 
								input: :vcf, 
								output: :vcf, 
								supports: [:snp, :indel],
								organism: [organisms(:human), organisms(:mouse)],
								model: {
									VariationAnnotation => [GeneticElement, Consequence, LossOfFunction]
								},
								active: false

	
end
