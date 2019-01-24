# == Description
# Performs annotation using CaptureKit

class CaptureKitAnnotation < Annotation

	@@CKCONFIG = nil
	@@CONFIGCACHE = {}
	# Load the configuration accoring to the Rails environment that we run under.
	def self.config(field)
		if @@CONFIGCACHE[field].nil? then
			conf = load_config()
			raise "Field #{field} not found in config for environment #{Rails.env}" if conf[field].nil?
			template = conf[field]
			ret = ERB.new(template.to_yaml).result(binding)
			ret = YAML.load(ret)
			@@CONFIGCACHE[field] = ret
		else
			ret = @@CONFIGCACHE[field]
		end
		ret
	end

	def self.run(cmd, out = CaptureKitAnnotation.logger.instance_variable_get("@logdev").dev, err = CaptureKitAnnotation.logger.instance_variable_get("@logdev").dev)
		cmds = ["set -o pipefail",
						"PATH=$PATH:#{CaptureKitAnnotation.bindir}",
						cmd]
		result = system("bash", "-c", cmds.join(";"), :out => out, :err => err)
		raise "FAILED #{cmd}" unless result.is_a?(TrueClass)
		true
	end

	def self.get_executable(cmd)
		tbxpath = `PATH=$PATH:#{CaptureKitAnnotation.bindir};which #{cmd}`.to_s.strip
		return tbxpath
	end

	def self.basedir
		get_dir('basedir')#CaddAnnotation.config('basedir')
	end

	def self.datadir(chr = nil)
		datadir = get_dir('datadir')
		datadir
	end

	def self.capturekitdir
		get_dir('capturekitdir')
	end

	def self.bindir
		get_dir('bindir')#
	end

	def self.workdir
		get_dir('workdir')
	end

	# If the initilizer is overwritten a call to super is neccessary to setup the VCFHEADER variable to parse a Vcf file.
	def initialize(opts = {})
		super # neccessary to setup @VCFHEADER
		## check setup vep file
		@capture_target_file_ids = opts[:capture_target_file_ids]
	end
	
	def self.ready?
		ready = super
		ready
	end
	
	# Executes annotation
	# == Parameters
	# [file_path] file to the minimal vcf/csv file containing missing variants
	# [input_vcf] VcfFile objects with the current vcf files
	def perform_annotation(file_path, input_vcf)
		begin
			self.class.log_info("BEGIN CaptureKitAnnotation annotation at #{Time.now}".cyan)
			output_files = do_annotation(file_path, input_vcf.organism_id)
			if output_files.nil?
				raise Exception.new("Annotation With CaptureKit failed.")
			end
			# we can now remove the input
			tarfile = archive(file_path, File.join(CaptureKitAnnotation.workdir, "#{input_vcf.id}_capturekit_#{Time.now.strftime("%y%m%d_%H%M%S")}_input.tar.gz"))
			self.class.log_info("FINISHED CaptureKitAnnotation Input archived to #{File.basename(tarfile)}".cyan)
		rescue => e
			self.class.log_fatal("#{e.message}: #{e.backtrace.pretty_print_inspect}")
			raise
		end
		return output_files
	end

	# returns a hash of all available CaptureKitFile objects for the given organism id as keys
	# Values are the results of the overlap between the CKF and the input_vcf_file
	def do_annotation(file, organism_id)
		# find relevant capture kits

		ckfs = CaptureKitFile.where(organism_id: organism_id)
		if !@capture_target_file_ids.nil? then
			ckfs = ckfs.where(id: @capture_target_file_ids)
		end
		results = {}
		if ckfs.size > 0 then
			ckfs.each do |ckf|
				results[ckf] = ckf.closest_feature(file)
			end
		else
			self.class.log_warn("No relevant target files for Organism##{organism_id}".yellow)
			return {}
		end
		results
	end
	
	# Executes storing procedures
	# == Parameters
	# [result] the result output file as returned by perform_annotation
	# [vcf] VcfFile objects with the current vcf file
	def store(results, vcf)
		self.class.log_info("BEGIN storing #{results.size} results...".cyan)
		files2archive = []
		threshold = (CaptureKitAnnotation.config('maxdist') || 5000).to_i
		results.each do |ckf, closest_feature_result_file|
			self.class.log_info("Storing CaptureKit #{closest_feature_result_file}...".blue)
			current_batch = []
			numcnt = 0
			offtarget = 0
			File.open(closest_feature_result_file) do |f|
				f.each_line do |line|
					vid, dist = line.strip.split("\t")
					dist = nil if dist.to_s == ""
					dist = nil if dist.to_s == "NA"
					dist = nil if dist.to_i > threshold
					current_batch << CaptureKit.new({
						variation_id: vid.to_i,
						organism_id: ckf.organism_id,
						capture_kit_file_id: ckf.id,
						dist: dist})
					numcnt += 1
					offtarget += 1 if dist.nil?
					if current_batch.size >= 5000 then
						SnupyAgain::DatabaseUtils.mass_insert(current_batch)
						current_batch = []
					end
				end
				SnupyAgain::DatabaseUtils.mass_insert(current_batch) # will not do anything if array is empty
			end
			files2archive << closest_feature_result_file
			self.class.log_info("Completed storing #{numcnt} records #{File.basename(closest_feature_result_file)}...#{offtarget} are off-target".blue)
		end
		tarfile = archive(files2archive, File.join(CaptureKitAnnotation.workdir, "#{vcf.id}_capturekit_#{Time.now.strftime("%y%m%d_%H%M%S")}_annot.tar.gz"))
		self.class.log_info("FINISHED Storing CaptureKit annotations for #{vcf.name} from #{tarfile}.".cyan)
		true
	end

	def archive(files, tarfile)
		files = [files] unless files.is_a?(Array)
		self.class.log_info("Archiving #{files.size} files to #{tarfile}".white)
		success = CaptureKitAnnotation.run("tar --transform 's/.*\\///g' --remove-files -zcvf #{tarfile} #{[files].flatten.map{|x| "'#{x}'"}.join(" ")}")
		raise "Could not archive annotations" unless success
		return tarfile
	end

	register_tool name:         :capture_kit,
				  label:              "Capture Kit Overlap",
				  input:              :vcf, # can be vcf or csv
				  output:             :vcf, # can be anything really, it is mostly used if your tool returns different outpuf formats
				  supports:           [:snp, :indel],
				  organism:           [organisms(:human), organisms(:mouse)], # other organisms can be added here
				  model:              [CaptureKit]

private
	def self.load_config(force = false)
		if @@CKCONFIG.nil? or force then
			yaml = File.join(Rails.root, "extras", "snupy_again", "aqua", "annotations" ,"capture_kit", "capture_kit.yaml")
			raise "config capture_kit.yaml not found" unless File.exists?(yaml)

			conf = YAML.load(File.open(yaml).read)
			raise "Config Environment not configured for #{Rails.env}" if conf[Rails.env].nil?
			@@CKCONFIG = conf[Rails.env]
		end
		@@CKCONFIG
	end

	def self.get_dir(config_name)
		dir = CaptureKitAnnotation.config(config_name)
		FileUtils.mkpath(dir ) unless Dir.exists?dir
		dir
	end

end