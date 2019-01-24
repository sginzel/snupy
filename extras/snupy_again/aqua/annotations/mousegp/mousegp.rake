namespace :mousegp do

	desc "Setup mousegp."
	task :setup => [:environment, :setup_vcfanno, :setup_bedops, :check_tools] do |t, args|
		# check if directory exists
		datadir = Mousegp.config('datadir')
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

	desc "Remove: Removes all traces of mousegp"
	task :remove => :environment do
		print "OK. DONE.\n"
	end

	desc "Clear: Removes all annotations done with mousegp"
	task :clear => :environment do
		CaptureKit.delete_all
		print "OK. DONE.\n"
	end

	desc "Clean mousegp - remove installation"
	task :clean => :environment do
		puts "Clear installation"
	end

	desc "Setup BedOps"
	task :setup_bedops do
		print "Setting up bedops...".blue
		bedopstar = File.join(CaptureKitAnnotation.bindir, File.basename(CaptureKitAnnotation.config('bedops_url')))
		download(CaptureKitAnnotation.config('bedops_url'), bedopstar) unless File.exists?(bedopstar)
		system("tar jxvf #{bedopstar} --strip-components=1 -C #{CaptureKitAnnotation.config('bindir')}") unless File.exist?(File.join(CaptureKitAnnotation.config('bindir'), 'bedops'))
		puts "DONE setting up bedops.".blue
	end

	desc "Check tools"
	task :check_tools do
		%w(bash grep gzip cat tar awk cut sed sort uniq tr bedops closest-features sort-bed vcf2bed).each do |cmd|
			check(cmd)
		end
	end

	desc "Populates the database with Capture Kit distances scores for all variations"
	task :populate => [:environment, :check_tools] do |t, args|
		# generate VCF file from all variants - the organism matters though
		## generate TSV of all variations available
		### Select human variation ids from variation calls
		### for batches of 100.000
		CaptureKitAnnotation.log_info("Starting Human Capture Kit population".blue)
		populate(Organism.human, CaptureKitFile.where(organism_id: Organism.human.id).pluck(:id))
		CaptureKitAnnotation.log_info("Starting Murine Capture Kit population".blue)
		populate(Organism.mouse, CaptureKitFile.where(organism_id: Organism.mouse.id).pluck(:id))
	end

	desc "Populates the database with a specific Capture Kit File. USAGE: bundle exec rake aqua:task[mousegp,add_mousegp_file,<mousegp_yaml_key e.g. AgilentHumanExomeV5plusUTR>]"
	task :add_mousegp_file, [:mousegp_file_name] => [:environment, :check_tools] do |t, args|
		# generate VCF file from all variants - the organism matters though
		## generate TSV of all variations available
		### Select human variation ids from variation calls
		### for batches of 100.000
		mousegp_file_names = args[:mousegp_file_name]
		if mousegp_file_names.nil? || mousegp_file_names.size == 0 then
			puts "No mousegp name given".yellow
			puts "USAGE: bundle exec rake aqua:task[mousegp,add_mousegp_file,<mousegp_yaml_key e.g. AgilentHumanExomeV5plusUTR>]".blue
			exit 1
		end
		mousegp_file_names = [mousegp_file_names] unless mousegp_file_names.is_a?(Array)
		# add mousegp to database
		mousegp_files = CaptureKitFile.create_from_config(mousegp_file_names)
		if (mousegp_files.size != mousegp_file_names.size) then
			STDERR.puts "Not all mousegp files could be found".red
			exit 1
		end
		mousegp_files.reject!(&:persisted?) # remove files already in the database.
		puts "Storing #{mousegp_files.size} new mousegp files".yellow
		mousegp_files.each do |ckf|
			ckf.save!
		end
		#mousegp_files = CaptureKitFile.where(name: mousegp_file_names).select([:id, :name, :organism_id, :localfile, :capture_type])
		if (mousegp_files.size == 0) then
			STDERR.puts "There are no new Capture Kit Files to add.".red
			exit 1
		end
		puts "Will add captured variants for #{mousegp_files.map(&:name).join(",")}".blue
		# split them by organism_id
		mousegp_files_by_org = {}
		mousegp_files.each do |ckf|
			mousegp_files_by_org[ckf.organism_id] ||= []
			mousegp_files_by_org[ckf.organism_id] << ckf
		end

		mousegp_files_by_org.each do |orgid, ckfs|
			organism = Organism.find(orgid)
			CaptureKitAnnotation.log_info("Adding mousegp #{ckfs.map(&:name)}".blue)
			populate(organism, ckfs.map(&:id))
		end
		#CaptureKitAnnotation.log_info("Starting Human Capture Kit population".blue)
		#populate(Organism.human, CaptureTargetFiles.where(organism_id: Organism.human.id).pluck(:id))
		#CaptureKitAnnotation.log_info("Starting Murine Capture Kit population".blue)
		#populate(Organism.mouse, CaptureTargetFiles.where(organism_id: Organism.mouse.id).pluck(:id))
	end

	def populate(organism, capture_target_file_ids = nil)
		orgname = organism.name.gsub(" ", "_")
		varidstore = "tmp/mousegp_varids#{orgname}.bin"
		batch_size = 500000
		varids = {}
		if (File.exists?(varidstore)) then
			puts "Previous population run detected. Do you want to resume it?[y/N]"
			if (STDIN.gets().strip.upcase == "Y") then
				puts "Using previous variation ids..."
				varids = load_object(varidstore)
#				varids.reject!{|batch| batch.size == 0}
			end
		end

		# find all varids
		if varids.size == 0 then
			# find all VCF Files for the specific organism
			vcfids = VcfFile.where(organism_id: organism.id).pluck(:id).sort
			# collect the coordinates from the indicies
			CaptureKitAnnotation.log_info("Collecting coordinates from #{vcfids.size} vcf files".yellow)
			vcfids.each do |vcfid|
				vidx = VcfFileIndex.where(vcf_file_id: vcfid).first
				if vidx.nil?
					CaptureKitAnnotation.log_warning("#{vcfid} has no index".magenta)
					next
				end
				vidx.each do |idxrecord|
					if varids[idxrecord[:variation_id]].nil?
						varids[idxrecord[:variation_id]] = %W(#{idxrecord[:chr]} #{idxrecord[:pos]} #{idxrecord[:variation_id]} #{idxrecord[:ref]} #{idxrecord[:alt]} 100 . VID=#{idxrecord[:variation_id]})
					end
				end
			end
			store_object(varids, varidstore)
			CaptureKitAnnotation.log_info("Collected #{varids.size} coordinates".yellow)
			CaptureKitAnnotation.log_info("Processing slice...".yellow)
			varids.keys.each_slice(batch_size) do |vids|
				varcoords = vids.map{|vid| varids[vid]}
				annotate_coordinates(varcoords, organism, capture_target_file_ids)
				vids.each{|vid| varids.delete(vid) }
				# update variation id store
				CaptureKitAnnotation.log_info("Updating #{varidstore}".magenta)
				store_object(varids, varidstore)
			end
			CaptureKitAnnotation.log_info("DONE populating database with mousegps".green)
		end
	end

	def annotate_coordinates(varcoords, organism, capture_target_file_ids)
		vcf_file_dummy = VcfFile.new(name: "dummy_#{varcoords.object_id}", organism_id: organism.id)
		CaptureKitAnnotation.log_info("-> Sorting #{varcoords.size} coordinates".yellow)
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
		CaptureKitAnnotation.log_info("-> Generating VCF file...".yellow)
		vcf = File.new("tmp/ck_variations_#{Time.now.to_i.to_s(36)}.vcf", "w+")
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
		CaptureKitAnnotation.log_info("-> Starting annotation process".yellow)
		# puts "#{vcf.path} generated"
		### use annotation class to annotate the variation vcf
		cka = CaptureKitAnnotation.new(capture_target_file_ids: capture_target_file_ids)
		results = cka.perform_annotation(vcf.path, vcf_file_dummy)
		### store annotations
		cka_file = cka.store(results, vcf_file_dummy)
		raise "CaptureKit annotation failed" unless cka_file.is_a?(TrueClass)
		CaptureKitAnnotation.log_info("-> Annotation successfull".green)
		cka_file
	end

	def populate_old(organism, capture_target_file_ids = nil)
		orgname = organism.name.gsub(" ", "_")
		vcf_file_dummy = VcfFile.new(name: "dummy_#{orgname}", organism_id: organism.id)

		varidstore = "tmp/mousegp_varids#{orgname}.bin"
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
			organism_samples = Sample.joins(:vcf_file_nodata)
														 .where("#{VcfFile.table_name}.organism_id" => organism.id)
														 .pluck("#{Sample.table_name}.#{Sample.primary_key}")
			puts "Retrieving variation calls for #{organism_samples.size} #{orgname} samples..."
			organism_samples = organism_samples.each_slice(10)
			varids = []
			organism_samples.each_with_index do |smplids, idx|
				print sprintf("%s / %s batches\r", idx.to_s, organism_samples.size)
				varids += VariationCall.where(sample_id: smplids)
											.uniq.pluck(:variation_id).sort
			end
			print sprintf("%s / %s batches DONE\n", organism_samples.size.to_s, organism_samples.size)
			# varids.uniq!
			varids = varids.each_slice(batch_size).to_a
			store_object(varids, varidstore)
			# File.open(varidyaml, "w+"){|f| f.write varids.to_yaml}
		end
		puts "Annotating #{varids.size} batches"

		#varids.each_slice(100).each do |variation_ids|
		(0...varids.size).each do |batchidx|
			CaptureKitAnnotation.log_info("Batch #{batchidx+1}/#{varids.size}.....".yellow)
			variation_ids = varids[batchidx]
			next if variation_ids.size == 0
			CaptureKitAnnotation.log_info("Retrieving coordinate for #{variation_ids.size} variants...".yellow)
			# retrival in smaller subbatches is a lot faster, because the server may chose to write a tmp table to the dist when many ids are given.
			varcoords = []
			variation_ids.each_slice(10000).each{|varids_btch|
				varcoords += Variation.joins([:region, :alteration])
												 .includes([:region, :alteration])
												 .where("#{Variation.table_name}.#{Variation.primary_key}" => varids_btch)
												 .map do |var|
					%W(#{var.region.name} #{var.region.start} #{var.id} #{var.alteration.ref} #{var.alteration.alt} 100 . VID=#{var.id})
				end
			}
			CaptureKitAnnotation.log_info("Sorting #{varcoords.size} coordinates".yellow)
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
			CaptureKitAnnotation.log_info("Generating VCF file...".yellow)
			vcf = File.new("tmp/ck_variations_batch_#{batchidx}.vcf", "w+")
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
			CaptureKitAnnotation.log_info("Starting annotation process".yellow)
			# puts "#{vcf.path} generated"
			### use annotation class to annotate the variation vcf
			cka = CaptureKitAnnotation.new(capture_target_file_ids: capture_target_file_ids)
			results = cka.perform_annotation(vcf.path, vcf_file_dummy)
			### store annotations
			cka_file = cka.store(results, vcf_file_dummy)
			raise "CaptureKit annotation failed" unless cka_file.is_a?(TrueClass)
			varids[batchidx] = []
			store_object(varids, varidstore)
		end
		# clean up
		CaptureKitAnnotation.log_info("Cleaning up variation id store".yellow)
		FileUtils.remove(varidstore)
		### convert tsv to vcf
	end

	# TODO we should have a method that allows the integration of new target regions.
	# we should also consider adding at least one set of genetic region list.

	def check(cmd)
		print "Checking #{cmd}..."
		tbxpath = CaptureKitAnnotation.get_executable(cmd)
		if tbxpath == ""
			print "#{tbxpath} NOT FOUND\n".red
			raise "#{cmd} does not exist in path" if tbxpath == ""
		end
		print "#{tbxpath} OK\n".green
	end

	def download(url, fname)
		if (url[0..3] == "file") then
			if File.exist?(url[7..-1])
				return url[7..-1]
			else
				raise "local file #{url} does not exist."
			end
		end
		print sprintf("Downloading %s -> %s".blue, File.basename(url), fname)
		bytes = IO.copy_stream(open(url), fname)
		puts sprintf("DONE %d bytes\n", bytes)
		fname
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