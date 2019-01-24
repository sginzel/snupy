class CaptureKitFile < ActiveRecord::Base
	@@CAPTUREKITCONFIG = YAML.load_file(File.join(Rails.root, "extras", "snupy_again", "aqua", "annotations" ,"capture_kit", "capture_kit.yaml"))[Rails.env]
	@@CKFILETABLENAME = "capture_kit_file#{@@CAPTUREKITCONFIG["version"].to_s.gsub(".", "_")}s".to_sym # there is a pending s to be confirm with RAILS pluralized table form
	self.table_name = @@CKFILETABLENAME

	# optional, but handy associations
	belongs_to :organism
	has_many :capture_kit, dependent: :delete_all

	# list all attributes here to mass-assign them
	attr_accessible :name,
									:description,
									:file,
									:localfile,
									:chromosomes,
									:bp,
									:capture_type,
									:content,
									:organism_id
	
	# optional method in case you want to do inheritance
	def self.aqua_table_alias
		self.table_name
	end

	def self.create_from_config(kits_to_create = [])
		ckfs = CaptureKitAnnotation.config('species').map do |species_name, kits|
			organism = Organism.find_by_name(species_name)
			kits.select{|kit_name, kit_config| (kit_config["active"] || true) }
			.map do |kit_name, kit_config|
				if kits_to_create.size > 0
					next unless kits_to_create.include?(kit_name)
				end
				ckf = CaptureKitFile.where(name: kit_name).first
				if (ckf.nil?)
					create_from_bed(kit_name,
													kit_config["description"].to_s,
													kit_config["capture_type"].to_s,
													organism.id,
													kit_config["file"])
				else
					ckf
				end
			end
		end
		ckfs.flatten.reject(&:nil?)
	end

	def self.create_from_bed(name, description, capture_type, organism_id, bed_file_path)
		# check if path exists
		raise "File #{bed_file_path} not found" unless File.exists?(bed_file_path)
		CaptureKitAnnotation.log_info("Create Capture Kit File from #{File.basename(bed_file_path)}")
		tmpfile = File.join(CaptureKitAnnotation.workdir, "tmp_#{File.basename(bed_file_path)}")
		# only keep the regions
		cmds = []
		cmds << "grep -v -e '^browser' -e '^track' '#{bed_file_path}'"
		cmds << "cut -f1,2,3"
		# remove chr prefix if required
		if (CaptureKitAnnotation.config('remove_chr')) then
			cmds << "sed 's/^chr//g'"
		end
		cmds << "sort"
		cmds << "uniq"
		cmds << "sort-bed - " # leaves file in lexicographical order
		cmds[-1] += " > '#{tmpfile}'"
		print "Extracting coordinates...".blue
		result = CaptureKitAnnotation.run(cmds.join(" | "))
		puts "DONE".green

		# get available chromosomes
		print "Extracting Chromosomes...".blue
		chromosomes=`cut -f1 '#{tmpfile}' | sort -V | uniq | tr "\n" ","`.strip[0..-2]
		puts "(#{chromosomes}) DONE".green

		# count number of bases
		print "Determining size...".blue
		num_bp = `cat '#{tmpfile}' | awk -F'\t' 'BEGIN{SUM=0}{ SUM+=$3-$2 }END{print SUM}'`.to_s.strip.to_i
		puts "#{num_bp}bp DONE".green
		# compress the result using gzip
		print "Compressing...".blue
		result = CaptureKitAnnotation.run("gzip -f '#{tmpfile}'")
		puts " DONE".green
		tmpfilegz = tmpfile + ".gz"
		content = File.open(tmpfilegz, 'rb'){|f| f.read}
		raise "Compressed file is still too large (#{bed_file_path})" if content.size > 50.megabytes

		md5sum = Digest::MD5.hexdigest content
		localfile = File.join(CaptureKitAnnotation.datadir, "#{md5sum}_#{File.basename(bed_file_path)}")

		if (!File.exists?localfile)
			print "Generating local file...".blue
			result = CaptureKitAnnotation.run("gunzip -c '#{tmpfile}' > '#{localfile}'")
			puts " DONE".green
			# create a new object
			ckf = CaptureKitFile.new({
					name: name,
					description: description,
					file: File.basename(bed_file_path),
					localfile: File.basename(localfile),
					chromosomes: chromosomes,
					bp: num_bp,
					capture_type: capture_type,
					content: content,
					organism_id: organism_id
			})
		else
			puts "Not doing anything #{localfile} already exists".red
			ckf = nil
		end

		print"Removing tmp file...".blue
		FileUtils.remove(tmpfilegz)
		puts "DONE".green
		CaptureKitAnnotation.log_info("   BP: #{num_bp}, CONTENT: #{content.size}")
		ckf
	end

	# returns the localfile within workdir of the object
	def localfile
		File.join(CaptureKitAnnotation.datadir, read_attribute(:localfile).to_s)
	end

	def localfile= (value)
		full_path = File.join(CaptureKitAnnotation.datadir, File.basename(value.to_s))
		if !File.exists?(full_path)
			errors.add(:localfile_doesnt_exist, "#{full_path} does not exist.")
			raise ActiveRecord::RecordInvalid.new(self)
		end
		write_attribute(:localfile, File.basename(value).to_s)
	end

	def closest_feature(local_vcf_file)
		result_file = File.join(CaptureKitAnnotation.workdir, File.basename(local_vcf_file, ".vcf") + "_capture_kit#{self.id}.tsv")
		cmds = get_closest_feature_command(local_vcf_file)
		cmds[-1] += " > '#{result_file}'"
		success = CaptureKitAnnotation.run(cmds.join(" | "))
		result_file
	end

	def get_closest_feature_command(local_vcf_file)
		cmds = []
		cmds << "cat #{local_vcf_file}"
		cmds << "vcf2bed"
		cmds << "cut -f1,2,3,4"
		cmds << "sort-bed - " # leaves file in lexicographical order - this is important when working with bedops
		cmds << "closest-features --dist --delim '#' --closest - #{localfile}"
		# file now has form of
		# VCF INPUT              #BED REGION HIT         #DISTANCE / can be NA
		# 10	92694	92695	4755559#10	100003787	100004047#99911093
		cmds << "sed 's/#.*#/\\t/'" # replace everything between the two # marks
		cmds << "cut -f4,5"        # keep only the VID and DIST columns
		cmds << "sed 's/NA//g'"   # replace NA with nothing
		cmds
	end

end

