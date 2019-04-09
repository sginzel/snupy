# == Description
# Performs annotation using Clinvar

class ClinvarAnnotation < Annotation
	
	# If the initilizer is overwritten a call to super is neccessary to setup the VCFHEADER variable to parse a Vcf file.
	def initialize(opts = {})
		super # neccessary to setup @VCFHEADER
		## check setup vep file
	end
	
	def self.ready?
		ready = super
		ready = ready && (!ClinvarAnnotation.vcf_file.nil?)
		ready
	end
	
	# transforms a Vcf Record (Vcf) to one or multiple Clinvar records
	#def parse_vcf_record(vcfp, varid)
	#
	#end
	
	# Executes annotation
	# == Parameters
	# [file_path] file to the minimal vcf/csv file containing missing variants
	# [input_vcf] VcfFile objects with the current vcf files
	def perform_annotation(file_path, input_vcf)
		output_file = nil
		begin
			species      = input_vcf.organism.name
			species_name = species.downcase.gsub(" ", "_")
			log_file       = File.join(Rails.root, "log", "clinvar_annotation.log")
			error_log_file = File.join(Rails.root, "log", "clinvar_annotation.error.log")
			cnt = do_annotation(file_path)
			if cnt.nil?
				raise Exception.new("Annotation failed.")
			end
			d "Annotation finished at #{Time.now}"
			tarfile = archive(file_path, File.join(ClinvarAnnotation.workdir, "#{input_vcf.id}_clinvar_#{Time.now.strftime("%y%m%d_%H%M%S")}_input.tar.gz"))
			self.class.log_info("FINISHED Storing #{cnt} annotations for #{input_vcf.name} from #{tarfile}.")

		rescue => e
			self.class.log_fatal("#{e.message}: #{e.backtrace.pretty_print_inspect}")
			raise
		end
		return file_path
	end
	
	def do_annotation(file)
		# do everything you need to do to perform the annotaiton
		# for each line of the input VCF
		## look for an exact match to the variant
		## if the current position of the clinvarVCF is larger than the current vcf coordinate
		## take the minimum distance of the current entry and create an association
		clinvaridx = ClinvarAnnotation.vcf_file.vcf_file_index
		@clinvaridx = clinvaridx.index # rebuilding the index object takes a while...
		@alterations = @clinvaridx.delete(:alterations)

		@evidence = {}
		ClinvarEvidence.all.each do |cle|
			@evidence[cle.alleleid] = cle
		end


		# Thes have to be used with the offset in the VCF file. Lets hope this actually worked...
		clinvcf = Vcf.new()
		@clinfile = File.new(Clinvar.local_vcf_file, "r")
		
		# outfile is a json file with attributes of the variants
		#outfile = File.join(ClinvarAnnotation.workdir,
		#							"#{File.basename(file).gsub(/.vcf$/,'')}_clinvar.csv")
		#fout = File.new(outfile, "w+")
		vcfp         = Vcf.new()
		clinvcfp     = Vcf.new()
		
		# build RB trees for all chromosome positions
		# remove :alterations
		indextrees = {}
		@clinvaridx.each do |chr, pos_to_rec|
			indextrees[chr] = RBTree[pos_to_rec.keys.each_with_index.to_a]
		end

		buffer = []
		cnt = 0
		lineno = 0
		File.open(file, "r").each_line do |line|
			if vcfp.parse_line(line)
				lineno+=1
				chr = vcfp.chrom
				pos = vcfp.pos.to_i
				ref = vcfp.ref
				alt = vcfp.alt
				vid = vcfp.info['VID'].to_i
				raise "Cannot annotate without VID field" if vid.nil?
				# use RBtrees to find upper and lower bounds for pos in chr
				# The lower and upper semantics dont make sense to me. So I will just swap this
				next if indextrees[chr].nil?
				upper = (indextrees[chr].lower_bound(pos) || []).first
				lower = (indextrees[chr].upper_bound(pos) || []).first

				clinpos = nil
				dist = nil
				if upper.nil? or lower.nil? then
					dist = (upper || lower) - pos
					clinpos = (upper || lower)
				elsif upper == lower then
					dist = 0
					clinpos = upper
				elsif (upper-pos).abs < (lower-pos).abs then
					dist = upper - pos
					clinpos = upper
				else
					dist = lower - pos
					clinpos = lower
				end

				#REMINDER: idx[chr][pos] << [stop, variation.id, variation.region_id, variation.alteration_id, offset]
				clinvarrec = @clinvaridx[chr][clinpos]
				clinvarrec.each do |stop, varid, regid, altid, offset|
					clinline = get_clinvar_line(offset)[offset]
					clinref, clinalt = @alterations[altid]
					clinvcfp.parse_line(clinline)
					alleleid = clinvcfp.info["ALLELEID"].to_i
					if (dist.abs <= 150) then
						evidence = @evidence[alleleid]
						evidence_dist = dist
						if evidence.nil? then
							evidence = ClinvarEvidence.create_new_from_record(clinvcfp.info, varid)
							@evidence[alleleid] = evidence
						end
					else
						evidence = ClinvarEvidence.new()
						evidence_dist = nil
					end
					buffer += Clinvar.parse_evidence(evidence, evidence_dist, vid, clinalt == alt && dist == 0).map{|attr| Clinvar.new(attr)}
					if buffer.size >= 5000 then
						cnt += buffer.size
						print("[#{lineno}] Writing #{buffer.size} clinvar evidence associations (#{cnt} total)                    \r")
						SnupyAgain::DatabaseUtils.mass_insert(buffer)
						buffer = []
					end
				end
			end
		end
		if (buffer.size > 0)
			cnt += buffer.size
			print("Writing #{buffer.size} clinvar evidence associations (#{cnt} total) ...")
			SnupyAgain::DatabaseUtils.mass_insert(buffer)
			print("DONE\n".green)
			buffer = []
		end
		#fout.close
		@clinfile.close

		success = true
		return nil if !success
		cnt
	end

	def get_clinvar_line(offsets)
		offsets = [offsets] unless offsets.is_a?(Array)
		if (@clinfile.nil? or @clinfile.closed?)
			@clinfile = File.new(Clinvar.local_vcf_file, "r")
		end
		result = {}
		offsets.each do |offset|
			@clinfile.seek(offset)
			result[offset] = @clinfile.readline
		end
		result
	end

	# Executes storing procedures
	# == Parameters
	# [result] the result output file as returned by perform_annotation
	# [vcf] VcfFile objects with the current vcf file
	def store(result, vcf)
		true # nothing to do
	end

	def archive(files, tarfile)
		files = [files] unless files.is_a?(Array)
		puts "Archiving #{files.size} files to #{tarfile}"
		success = ClinvarAnnotation.run("tar --transform 's/.*\\///g' --remove-files -zcvf #{tarfile} #{files.map{|x| "'#{x}'"}.join(" ")}")
		raise "Could not archive clinvar annotations" unless success
		return tarfile
	end

	register_tool name:               :clinvar,
				  label:              "Clinvar",
				  input:              :vcf,
				  output:             nil,
				  supports:           [:snp, :indel], # prevent annotation processes to be started for this class
				  organism:           [organisms(:human)],
				  model:              [Clinvar],
				  active: true # use this to activate your annotation once it is ready
		
	
	
	# Requireed methods to load and work with configurations
	@@CKCONFIG    = nil
	@@CONFIGCACHE = {}
	# Load the configuration accoring to the Rails environment that we run under.
	def self.config(field)
		if @@CONFIGCACHE[field].nil? then
			conf = load_config()
			raise "Field #{field} not found in config for environment #{Rails.env}" if conf[field].nil?
			template             = conf[field]
			ret                  = ERB.new(template.to_yaml).result(binding)
			ret                  = YAML.load(ret)
			@@CONFIGCACHE[field] = ret
		else
			ret = @@CONFIGCACHE[field]
		end
		ret
	end
	
	def self.run(cmd, out = ClinvarAnnotation.logger.instance_variable_get("@logdev").dev, err = ClinvarAnnotation.logger.instance_variable_get("@logdev").dev)
		cmds   = ["set -o pipefail",
				  "PATH=$PATH:#{ClinvarAnnotation.bindir}",
				  cmd]
		result = system("bash", "-c", cmds.join(";"), :out => out, :err => err)
		raise "FAILED #{cmd}" unless result.is_a?(TrueClass)
		true
	end
	
	def self.get_executable(cmd)
		tbxpath = `PATH=$PATH:#{ClinvarAnnotation.bindir};which #{cmd}`.to_s.strip
		return tbxpath
	end
	
	def self.basedir
		get_dir('basedir') #CaddAnnotation.config('basedir')
	end
	
	def self.datadir(chr = nil)
		datadir = get_dir('datadir')
		datadir
	end
	
	def self.bindir
		get_dir('bindir') #
	end
	
	def self.workdir
		get_dir('workdir')
	end
	
	def self.local_vcf_file()
		File.join(ClinvarAnnotation.datadir,
		          File.basename(ClinvarAnnotation.config("vcf"), ".gz"))
	end
	
	def self.vcf_file()
		VcfFile.where(name: File.basename(ClinvarAnnotation.local_vcf_file)).first
	end
	
	private
	def self.load_config(force = false)
		if @@CKCONFIG.nil? or force then
			yaml = File.join(Aqua.annotationdir ,"clinvar", "clinvar_config.yaml")
			raise "config #{yaml} not found" unless File.exists?(yaml)
			
			conf = YAML.load(File.open(yaml).read)
			raise "Config Environment not configured for #{Rails.env}" if conf[Rails.env].nil?
			@@CKCONFIG = conf[Rails.env]
		end
		@@CKCONFIG
	end
	
	def self.get_dir(config_name)
		dir = ClinvarAnnotation.config(config_name)
		FileUtils.mkpath(dir ) unless Dir.exists?dir
		dir
	end
	
end