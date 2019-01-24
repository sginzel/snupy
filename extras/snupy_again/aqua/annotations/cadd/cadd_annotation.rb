# == Description
# Performs annotation using Cadd

class CaddAnnotation < Annotation
	
	@@CADDCONFIG = nil
	@@CONFIGCACHE = {}
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

	def self.datafiles()
		return {} unless File.exists?(File.join(config('datadir'), 'datafiles.yaml'))
		datafiles_yaml = File.join(config('datadir'), 'datafiles.yaml')
		File.open(datafiles_yaml){|f|
			YAML.load(f)
		}
	end

	def self.store_datafiles(datafiles)
		datafiles_yaml = File.join(config('datadir'), 'datafiles.yaml')
		File.open(datafiles_yaml, 'w+') do |f|
			f.write(datafiles.to_yaml)
		end
	end

	# If the initilizer is overwritten a call to super is neccessary to setup the VCFHEADER variable to parse a Vcf file.
	def initialize(opts = {})
		super # neccessary to setup @VCFHEADER
		## check setup vep file
	end
	
	
	def self.ready?
		# Check files
		ready = datafiles.all?{|chr,confs|
			confs.all?{|k,v|
				File.exists?(k) && File.exists?(v)
			}
		}

		ready
	end
	
	# Executes annotation
	# == Parameters
	# [file_path] file to the minimal vcf/csv file containing missing variants
	# [input_vcf] VcfFile objects with the current vcf files
	def perform_annotation(file_path, input_vcf)
		output_file = nil
		begin
			log_file       = File.join(Rails.root, "log", "cadd_annotation.log")
			error_log_file = File.join(Rails.root, "log", "cadd_annotation.error.log")
			output_file = do_annotation(file_path, input_vcf)
			if output_file.nil?
				raise Exception.new("Annotatil failed.")
			end
			self.class.log_info "Annotation finished at #{Time.now}"
		rescue => e
			self.class.log_fatal("#{e.message}: #{e.backtrace.pretty_print_inspect}")
			raise
		end
		return output_file
	end
	
	def do_annotation(full_file, input_vcf)
		raise "Only human is supported" unless input_vcf.organism_id == Organism.human.id
		# we need to split up the file by its chromosomes.
		# Then for each file we do the annotation per chromosome
		datafiles = self.class.datafiles
		## after splitting the vcf file, the full_file will be deleted
		chr_vcf_files = split_vcf_file_by_chromsome(full_file, datafiles.keys)
		if chr_vcf_files.size > 0 then
			FileUtils.remove(full_file)
		else
			raise "Splitting failed or input is empty."
		end
		# execute annotation in parallel
		results = Parallel.map(chr_vcf_files, in_threads: (CaddAnnotation.config('num_parallel_vcf_annotation').to_i || 1)) do |chr, file|
		#chr_vcf_files.each do |chr, file|
			#results += [self.class.vcfanno(file, chr)].flatten
			[self.class.vcfanno(file, chr)].flatten
		end
		results.flatten!
		# Archive the input
		archive(chr_vcf_files.values.flatten,
						File.join(CaddAnnotation.workdir, "#{input_vcf.id}_cadd_#{Time.now.strftime("%y%m%d_%H%M%S")}_input.tar.gz"))

		# results is a array of successfully annotated vcf files
		# go through all results and collect the results
		return nil if results.nil? || results.any?(&:nil?)
		results
	end

	def split_vcf_file_by_chromsome(full_file, chromosomes)
		files = {}
		puts "Splitting #{full_file} into #{chromosomes.size} chromosomes"
		chromosomes.each do |chr|
			chr_split = File.join(
													CaddAnnotation.workdir,
													File.basename(full_file, ".vcf") + ".chr#{chr}.vcf"
			)
			cmds = ["cat '#{full_file}' | grep '#' > '#{chr_split}'",
							"cat '#{full_file}' | grep -v '#' | grep -P '^#{chr}\\t' >> '#{chr_split}' || echo -n ''"] # echo -n prevents the function from failing if there are no variants on the chromosome.
			cmds.each do |cmd|
				CaddAnnotation.run(cmd)
			end
			num_lines = `cat #{chr_split} | grep -v "#" | head | wc -l`.to_s.strip.to_i
			files[chr] = chr_split if num_lines > 0
		end
		files
	end
	
	def self.vcfanno(file, chr = nil)
		success = false
		chr_datafiles = datafiles
		if (chr.nil?)
			chr_datafiles.values.flatten
		else
			chr_datafiles = chr_datafiles[chr]
		end
		results = chr_datafiles.map do |cadd_scores, vcfannoconf|
			cadd_source_name = File.basename(cadd_scores, ".gz.tsv.vcf.gz")
			outfile = File.join(CaddAnnotation.workdir,
			                    "#{File.basename(file).gsub(/.vcf$/,'')}_#{cadd_source_name}.cadd.vcf")
			success = run_vcfanno(file, outfile, vcfannoconf)
			outfile
		end
		return nil if results.any?{|f| f.nil?}
		return nil if results.any?{|f| !File.exists?(f)}
		return results
	end

	def self.run_vcfanno(infile, outfile, conf, procs = (CaddAnnotation.config('vcfanno_procs') || 2))
		vcfanno = CaddAnnotation.config('vcfanno')
		success = self.run("#{vcfanno} -p #{procs} #{conf} #{infile} > '#{outfile}'")
		success
	end

	def self.run(cmd, out = CaddAnnotation.logger.instance_variable_get("@logdev").dev, err = CaddAnnotation.logger.instance_variable_get("@logdev").dev)
		cmds = ["set -o pipefail",
						"PATH=$PATH:#{CaddAnnotation.bindir}",
						cmd]
		result = system("bash", "-c", cmds.join(";"), :out => out, :err => err)
		raise "FAILED #{cmd}" unless result.is_a?(TrueClass)
		true
	end

	def self.run_plain(cmd)
		cmds = ["set -o pipefail",
						"PATH=$PATH:#{CaddAnnotation.bindir}",
						cmd]
		# result = system(cmds.join(";"))
		result = system("bash", "-c", cmds.join(";"))
		raise "FAILED #{cmd}" unless result.is_a?(TrueClass)
		true
	end

	def self.get_executable(cmd)
		tbxpath = `PATH=$PATH:#{CaddAnnotation.bindir};which #{cmd}`.to_s.strip
		return tbxpath
	end
	
	def self.basedir
		get_dir('basedir')#CaddAnnotation.config('basedir')
	end
	
	def self.datadir(chr = nil)
		datadir = get_dir('datadir')
		if !chr.nil? then
			datadir = File.join(datadir, "chromosomes", chr.to_s)
			FileUtils.mkpath(datadir) unless Dir.exists?datadir
		end
		datadir
	end

	def self.targetdir
		get_dir('targetdir')
	end

	def self.bindir
		get_dir('bindir')#
	end
	
	def self.workdir
		get_dir('workdir')
	end

	# Executes storing procedures
	# == Parameters
	# [result] the result output file as returned by perform_annotation
	# [vcf] VcfFile objects with the current vcf file
	def store(results, vcf)
		# results is a list of successfully annotated vcf files that contain the CADD scores.
		# go through all of them and collect the variations that were or were not annotated
		cadd_score = {}
		# results is a array of outputs. We iterate this result and collect annotation for all variation ids
		cadd_score = Hash.new(false) # used to keep track of inserted cadd scores
		cadd_score_missing = {}
		current_batch = []
		annot_cnt = 0
		vcfp = Vcf.new()
		organism_id = vcf.organism_id
		self.class.log_info "Begin to store #{Time.now} #{results.size} files..."
		results.each do |cadd_vcf|
			self.class.log_info "Collecting data from #{File.basename(cadd_vcf)}"
			File.open(cadd_vcf, 'r') do |fin|
				fin.each_line do |line|
					if vcfp.parse_line(line) then
						vid = vcfp.info['VID'].to_i
						if vcfp.info['cadd_phred'].to_s != ""
							if !cadd_score[vid] then # already has non-null cadd score
								current_batch << Cadd.new({
																							variation_id: vcfp.info['VID'].to_i,
																							organism_id: organism_id.to_i,
																							phred: vcfp.info['cadd_phred'],
																							raw: vcfp.info['cadd_raw']}
								)
								annot_cnt += 1
								cadd_score_missing.delete(vid) # make sure it is removed from missing annotations
								cadd_score[vid] = true
							end
						else
							cadd_score_missing[vid] = true unless cadd_score[vid] # make sure its not marked missin if it already has a value
						end
						if current_batch.size >= 5000 then
							SnupyAgain::DatabaseUtils.mass_insert(current_batch)
							current_batch = []
						end
					end
				end
				if current_batch.size >= 0 then
					SnupyAgain::DatabaseUtils.mass_insert(current_batch)
					current_batch = []
				end
			end
		end
		## make sure to add NULL values for missing annotations
		cadd_score_missing.select!{|k,v| v}
		cadd_score_missing.keys.each_slice(5000) do |vids|
			SnupyAgain::DatabaseUtils.mass_insert(vids.map{|vid|
				Cadd.new({
										 variation_id: vid,
										 organism_id: organism_id.to_i,
										 phred: nil,
										 raw: nil
								 })
			})
			annot_cnt += vids.size
		end
		tarfile = archive(results, File.join(CaddAnnotation.workdir, "#{vcf.id}_cadd_#{Time.now.strftime("%y%m%d_%H%M%S")}_annot.tar.gz"))
		self.class.log_info("FINISHED Storing #{annot_cnt} annotations for #{vcf.name} from #{tarfile}. #{cadd_score_missing.size} dont have a cadd score.")
		true
	end
	
	def archive(files, tarfile)
		puts "Archiving #{files.size} files to #{tarfile}"
		success = CaddAnnotation.run("tar --transform 's/.*\\///g' --remove-files -zcvf #{tarfile} #{files.map{|x| "'#{x}'"}.join(" ")}")
		raise "Could not archive annotations" unless success
		return tarfile
	end
	
	register_tool name:               :cadd,
				  label:              "cadd",
				  input:              :vcf, # can be vcf or csv
				  output:             :vcfs, # can be anything really, it is mostly used if your tool returns different outpuf formats
				  supports:           [:snp, :indel],
				  organism:           [organisms(:human)], # other organisms can be added here
				  model:              [Cadd],
				  active:             true,
				  quantiles: {
					  Cadd => {
						  :phred => 1,
						  :raw => 1
					  }
				  }

private
	def self.load_config(force = false)
		if @@CADDCONFIG.nil? or force then
			yaml = File.join(Rails.root, "extras", "snupy_again", "aqua", "annotations" ,"cadd", "cadd.yaml")
			raise "config cadd.yaml not found" unless File.exists?(yaml)
			
			conf = YAML.load(File.open(yaml).read)
			raise "Config Environment not configured for #{Rails.env}" if conf[Rails.env].nil?
			@@CADDCONFIG = conf[Rails.env]
		end
		@@CADDCONFIG
	end
	
	def self.get_dir(config_name)
		dir = CaddAnnotation .config(config_name)
		FileUtils.mkpath(dir ) unless Dir.exists?dir
		dir
	end
end
