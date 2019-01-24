namespace :cadd do
	
	desc "Setup cadd."
	task :setup => [:environment, :setup_vcfanno, :setup_bedops, :setup_cadd_to_vcf, :setup_merge_bed_regions, :check_tools] do |t, args|
		# check if directory exists
		datadir = CaddAnnotation.config('datadir')
		FileUtils.mkpath(datadir) unless Dir.exists?datadir
		
		# generate a score file from the targets
		target_files = generate_target_file()
		datafiles = {}
		target_files.each do |chr, target_file|
			datafiles[chr] = CaddAnnotation.config('urls').map do |url|
				fname = File.join(CaddAnnotation.datadir(chr), "#{File.basename(url, ".tsv.gz")}_on_#{File.basename(target_file, ".bed")}_#{chr}.tsv")
				fname_vcf = "#{fname}.vcf"
				fname_vcfgz = "#{fname_vcf}.gz"
				if !File.exists?(fname_vcfgz) then
					printf("Processing #{url} and reducing to #{File.basename(target_file)}...")
					# in case a local file is referenced
					if (url[0..3] == "file") then
						url = url[7..-1]
						raise "#{url} not found" if !File.exists?(url)
					end
					# system("tabix -R '#{target_file}' '#{url}' | bgzip > '#{fname}' ", :out => File::NULL)
					cmds = [
							"tabix -R '#{target_file}' '#{url}'",
							"#{CaddAnnotation.bindir}/cadd_tsv_to_vcf",
							#"sort -V -k1 -k2 -k4", # do not ever do this
							"bgzip -c > '#{fname_vcfgz}'"
					]
					puts ":........:"
					puts cmds.join(" | ")
					puts ":........:"
					CaddAnnotation.run(cmds.join(" | "))
					#CaddAnnotation.run("tabix -R '#{target_file}' '#{url}' > '#{fname}' ", File::NULL)
					# fname now is a tsv
					#tsv_to_vcf(fname, fname_vcf)
					#CaddAnnotation.run("cat '#{fname_vcf}' | bgzip -c > '#{fname_vcfgz}'", File::NULL)
					# generate tbi
					CaddAnnotation.run("tabix -p vcf '#{fname_vcfgz}' ")
					puts "DONE -> #{fname_vcfgz}"
				else
					puts "File #{fname_vcfgz} already exists!"
				end
				fname_vcfgz
			end
		end

		# CaddAnnotation.store_datafiles(datafiles)

		# create config for each data file
		datafile_confs = {}
		datafiles.each do |chr, chr_datafiles|
			datafile_confs[chr] = {}
			chr_datafiles.each do |datafile|
				puts "Generating vcfanno conf for #{datafile}"
				vcfannoconf = "#{datafile}.vcfanno"
				cadd_conf_template = File.join(Rails.root, 'extras', 'snupy_again', 'aqua', 'annotations', 'cadd', 'vcfanno_cadd.conf.erb')
				cadd_conf_template = File.open(cadd_conf_template, "r").read
				File.open(vcfannoconf, 'w+') do |f|
					f.write ERB.new(cadd_conf_template).result(binding)
				end
				datafile_confs[chr][datafile] = vcfannoconf
			end
		end
		CaddAnnotation.store_datafiles(datafile_confs)

		puts "Done setting up CADD. You may use bundle exec rake aqua:task[cadd,populate] to pre-populate the database"
	end
	
	desc "Populates the database with CADD scores for all variations"
	task :populate => [:environment, :check_tools] do |t, args|
		# generate VCF file from all variants - the organism matters though
		## generate TSV of all variations available
		### Select human variation ids from variation calls
		### for batches of 100.000
		vcf_file_dummy = VcfFile.new(name: "dummy", organism_id: 1)
		
		varidstore = "tmp/cadd_varids.bin"
		batch_size = 100000
		varids = []
		if (File.exists?(varidstore)) then
			puts "Previous population run detected. Do you want to resume it?[y/N]"
			if (STDIN.gets().strip.upcase == "Y") then
				puts "Using previous variation ids..."
				varids = load_object(varidstore)
				varids.reject!{|batch| batch.size == 0}
			end
		end
		if varids.size == 0 then
			human_samples = Sample.joins(:vcf_file_nodata)
				                .where("#{VcfFile.table_name}.organism_id" => Organism.human.id)
				                .pluck("#{Sample.table_name}.#{Sample.primary_key}")
			puts "Retrieving variation calls for #{human_samples.size} samples..."
			human_samples = human_samples.each_slice(10)
			varids = []
			human_samples.each_with_index do |smplids, idx|
				print sprintf("%s / %s batches\r", idx.to_s, human_samples.size)
				varids += VariationCall.where(sample_id: smplids)
					         .uniq.pluck(:variation_id).sort
			end
			print sprintf("%s / %s batches DONE\n", human_samples.size.to_s, human_samples.size)
			varids.uniq!
			puts "Found #{varids.size} variant...Determine existing CADD"
			varids_exist = Cadd.uniq.pluck(:variation_id).sort
			puts "#{varids_exist.size} CADD scores available..."
			puts "#{varids.size - varids_exist.size} variants need annotation..."
			varids = (varids - varids_exist).each_slice(batch_size).to_a
			store_object(varids, varidstore)
			# File.open(varidyaml, "w+"){|f| f.write varids.to_yaml}
		end
		puts "Annotating #{varids.size} batches"
		
        #varids.each_slice(100).each do |variation_ids|
		(0...varids.size).each do |batchidx|
			puts "[CADD-populate] Batch #{batchidx+1}/#{varids.size}....."
			variation_ids = varids[batchidx]
			next if variation_ids.size == 0
			varcoords = Variation.joins([:region, :alteration])
					.includes([:region, :alteration])
					.where("#{Variation.table_name}.#{Variation.primary_key}" => variation_ids)
					.map do |var|
				%W(#{var.region.name} #{var.region.start} #{var.id} #{var.alteration.ref} #{var.alteration.alt} 100 . VID=#{var.id})
			end
			chr_order = ((1..22).to_a + ["X", "Y", "M", "MT"])
			chr_order = Hash[chr_order.map{|x| [x.to_s, chr_order.index(x)]}]
			varcoords.sort!{|x,y|
				# check chromsome first
				res = 0
				if chr_order[x[0]] == chr_order[y[0]] then
					if x[1] == y[1] then
						res = x[4] <=> y[4] # sort by alt
					else
						res = x[1].to_i <=> y[1].to_i # sort by pos
					end
				else
					res = chr_order[x[0]] <=> chr_order[y[0]]
				end
				res
			}
			### generate VCF
			vcf = File.new("tmp/variations_batch.vcf", "w+")
			vcf.write(<<EOS
##fileformat=VCFv4.1
##INFO=<ID=VID,Number=1,Type=Float,Description="Snupy variation id">
#CHROM	POS	ID	REF	ALT	QUAL	FILTER	INFO
EOS
				)
			varcoords.each do |coord|
				vcf.write(coord.join("\t") + "\n")
			end
			vcf.close
			# puts "#{vcf.path} generated"
			### use annotation class to annotate the variation vcf
			cadd = CaddAnnotation.new()
			results = cadd.perform_annotation(vcf.path, vcf_file_dummy)
			### store annotations
			cadd_file = cadd.store(results, vcf_file_dummy)
			raise "CADD annotation failed" unless cadd_file.is_a?(TrueClass)
			varids[batchidx] = []
			store_object(varids, varidstore)
		end
		# clean up
		FileUtils.remove(varidstore)
		### convert tsv to vcf

	end
	
	desc "Remove: Removes all traces of cadd"
	task :remove => :environment do
		print "OK. DONE.\n"
	end

	desc "Clear: Removes all annotations done with cadd"
	task :clear => :environment do
		Cadd.delete_all
		print "OK. DONE.\n"
	end
	
	desc "Clean cadd - remove installation"
	task :clean => :environment do
		puts "Clear installation"
	end

	desc "Setup vcfanno"
	task :setup_vcfanno do
		# download vcf anno
		puts "Setting up vcfanno..."
		vcfanno = CaddAnnotation.config('vcfanno')
		#cadd2vcf = CaddAnnotation.config('cadd2vcf')
		download(CaddAnnotation.config('vcfanno_url'), vcfanno) unless File.exists?(vcfanno)
		#download(CaddAnnotation.config('cadd2vcf_url'), cadd2vcf)
		FileUtils.chmod_R "u=wrx", vcfanno
		#FileUtils.chmod_R "u=wrx", cadd2vcf
		puts "DONE setting up vcfanno..."
	end

	desc "Setup vcfanno"
	task :setup_bedops do
		puts "Setting up bedops..."
		bedopstar = File.join(CaddAnnotation.bindir, File.basename(CaddAnnotation.config('bedops_url')))
		download(CaddAnnotation.config('bedops_url'), bedopstar) unless File.exists?(bedopstar)
		# puts("tar jxvf #{bedopstar} --strip-components=1 -C #{CaddAnnotation.config('bindir')}") unless File.exist?(File.join(CaddAnnotation.config('bindir'), 'gff2bed'))
		system("tar jxvf #{bedopstar} --strip-components=1 -C #{CaddAnnotation.config('bindir')}") unless File.exist?(File.join(CaddAnnotation.config('bindir'), 'gff2bed'))
		puts "DONE setting up bedops."
	end
	
	desc "Setup cadd to vcf"
	task :setup_cadd_to_vcf do
		puts "Setting up cadd to vcf..."
		scriptfile = File.join(CaddAnnotation.bindir, "cadd_tsv_to_vcf")
		FileUtils.copy( File.join(File.dirname(CaddAnnotation.basedir), "cadd_tsv_to_vcf"),
		                scriptfile
		               )
		system("chmod ugo+x #{scriptfile}")
		raise "Copy didnt work" unless File.exists?(scriptfile)
		puts "DONE setting up cadd to vcf."
	end
	
	desc "Setup merge bed regions"
	task :setup_merge_bed_regions do
		puts "Setting up merge_bed_regions..."
		scriptfile = File.join(CaddAnnotation.bindir, "merge_bed_regions")
		FileUtils.copy( File.join(File.dirname(CaddAnnotation.basedir), "merge_bed_regions"),
		                scriptfile
		)
		system("chmod ugo+x #{scriptfile}")
		raise "Copy didnt work" unless File.exists?(scriptfile)
		puts "DONE setting up merge_bed_regions."
	end
	
	desc "Check tools"
	task :check_tools do
		%w(bash head tabix bgzip vcfanno gff2bed cat zcat tar awk bedops pv cadd_tsv_to_vcf merge_bed_regions sort-bed).each do |cmd|
			check(cmd)
		end
	end

	def check(cmd)
		print "Checking #{cmd}..."
		tbxpath = CaddAnnotation.get_executable(cmd)
		raise "#{cmd} does not exist in path" if tbxpath == ""
		print "#{tbxpath} OK\n"
	end

	def download(url, fname)
		if (url[0..3] == "file") then
			if File.exist?(url[7..-1])
				return url[7..-1]
			else
				raise "local file #{url} does not exist."
			end
		end
		puts sprintf("Downloading %s -> %s", url, fname)
		bytes = IO.copy_stream(open(url), fname)
		puts sprintf("DONE %d bytes\n", bytes)
		fname
	end

	def generate_target_file
		targets = CaddAnnotation.config('targets').map do |target_file|
			if (target_file =~ /.gff3.gz$/)
				local_target = generate_target_file_from_gff(target_file)
			elsif (target_file =~ /.bed$/)
				local_target = generate_target_file_from_bed(target_file)
			else
				raise "I dont know how to handle the target #{target_file}"
			end
			raise "#{local_target} could not be generted" unless File.exists?local_target
			local_target
		end
		target_file = merge_bed_files(targets)
		split_target_file(target_file)
	end

	# splits a bed file by its chromome and return an hash of new bed files chr => chr_specific_bed_file
	def split_target_file(target_file, chromsomes = ((1..22).to_a + ["X", "Y"]))
		targets = chromsomes.map{|chr|
			chr_target_file_name = File.join(File.dirname(target_file), File.basename(target_file, ".bed") + "_#{chr}.bed")
			CaddAnnotation.run("grep -P '^#{chr}\t' #{target_file} > #{chr_target_file_name}" )
			[chr.to_s, chr_target_file_name]
		}
		Hash[targets]
	end

	def generate_target_file_from_bed(target_file)
		local_file = File.join(CaddAnnotation.datadir, File.basename(target_file))
		download(target_file, local_file)
	end
	
	def generate_target_file_from_gff(target_file)
		target_file_name = File.basename(target_file)
		local_targetgz  = File.join(CaddAnnotation.datadir, target_file_name)
		local_target = File.join(CaddAnnotation.datadir, File.basename(local_targetgz, ".gff.gz") + ".bed")
		
		# download
		local_targetgz = download(target_file, local_targetgz) unless File.exists?local_targetgz
		
		# extract & filter local target
		# convert gff to bed
		if !File.exist?(local_target ) then
			features = CaddAnnotation.config('target_features').map{|f| "$3 == \"#{f}\""}
			cmds = [
					"zcat -f #{local_targetgz}",
					"awk '#{features.join(" || ")}'",
					"gff2bed",
					"bedops --merge -",
					"merge_bed_regions",
					"sort -V -k1 -k2 -k3 > #{local_target}"
			]
			CaddAnnotation.run_plain(cmds.join(" | "))
		end
		local_target
	end
	
	def merge_bed_files(targets)
		target_files = targets.map{|f| "'#{f}'"} # quote them
		result_file = File.join(CaddAnnotation.targetdir, "merged_targets.bed")
		target_padding = CaddAnnotation.config('target_padding')
		if (!File.exists?result_file) then
			puts "Generating #{File.basename(result_file)} from #{targets.size} targets..."
			# puts("bedops --everything #{target_files.join(" ")} | sort-bed - > '#{result_file}' ")
			# "sort -V -k1,1 -k2,2 -k3,3"
			#CaddAnnotation.run("bedops --everything #{target_files.join(" ")} | sort-bed - > '#{result_file}' ")
			# we need to execute bedops --merge multiple times because it is only able to deal with _PAIRS_ of consequtive regions. Or there is a bug in general
			CaddAnnotation.run("bedops --merge #{target_files.join(" ")} | bedops --range #{target_padding} --merge - | merge_bed_regions | sort -V -k1 -k2 -k3 > '#{result_file}' ")
			# For some reason bed-sort does not sort the bed file...
			# CaddAnnotation.run("bedops --everything #{target_files.join(" ")} | sort -V -k1 -k2 -k3 > '#{result_file}' ")
		else
			puts "#{result_file} already exists."
		end
		result_file
	end

	def tsv_to_vcf(cadd_tsv, cadd_vcf)
		fin = File.new(cadd_tsv, 'r')
		fot= File.new(cadd_vcf, 'w+')
		puts sprintf("Converting to %s", cadd_vcf)
		fot.write(<<EOS
##fileformat=VCFv4.1
##INFO=<ID=raw,Number=1,Type=Float,Description="raw cadd score">
##INFO=<ID=phred,Number=1,Type=Float,Description="phred-scaled cadd score">
##CADDCOMMENT=<ID=comment,comment="COMMENT">
#CHROM	POS	ID	REF	ALT	QUAL	FILTER	INFO
EOS
)
		fin.each_line do |line|
			next if line[0] == "#"
			line.strip!
			cols = line.split("\t")
			fot.printf("%s\t%s\t.\t%s\t%s\t1\tPASS\traw=%s;phred=%s\n",
			            cols[0],cols[1],cols[2],cols[3],cols[4],cols[5])
		end
		
		fot.close
		puts sprintf("DONE", cadd_vcf)
		cadd_vcf
	end
	
	
	def store_object(obj, filename)
		File.open(filename, 'w+'){|f|
			Marshal.dump(obj, f)
		}
	end
	
	def load_object(filename)
		File.open(filename, 'r'){|f|
			Marshal.load(f)
		}
	end
end
