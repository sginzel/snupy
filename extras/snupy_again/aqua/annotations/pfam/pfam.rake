namespace :pfam do
	
	desc "Setup pfam."
	task :setup => [:environment, :setup_dependencies, :check_tools] do |t, args|
		# Do everything neccessary to setup your tool
		# You can also define tasks and add them to the dependency chain
	end

	desc "Remove: Removes all traces of pfam"
	task :remove => :environment do
		print "OK. DONE.\n"
	end

	desc "Clear: Removes all annotations done with pfam"
	task :clear => :environment do
		Pfam.delete_all
		print "OK. DONE.\n"
	end
	
	desc "Clean pfam - remove installation"
	task :clean => :environment do
		puts "Clear installation"
	end

	desc "Setup Dependencies pfam"
	task :setup_dependencies do
		print "Setting up dependencies...".blue
		local_tool_file = File.join(PfamAnnotation.bindir, "some_tool")
		download(PfamAnnotation.config('some_url'), local_tool_file) unless File.exists?(local_tool_file)
		puts "DONE setting up dependencies.".blue
	end

	desc "Checks a list of tools"
	task :check_tools do
		%w(bash grep gzip cat tar awk cut sed sort uniq tr).each do |cmd|
			check(cmd)
		end
	end

	desc "Populates the database with Capture Kit distances scores for all variations"
	task :populate => [:environment, :check_tools] do |t, args|
		PfamAnnotation.configuration[:organism].each do |organism|
			PfamAnnotation.log_info("Starting Pfam for #{organism.name}".blue)
			populate(organism)
		end
	end

	def check(cmd)
		print "Checking #{cmd}..."
		tbxpath = PfamAnnotation.get_executable(cmd)
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
		print sprintf("Downloading %s -> %s...".blue, File.basename(url), fname)
		if !(File.exists? fname) then
			bytes = IO.copy_stream(open(url), fname)
			print sprintf("DONE %d bytes\n".blue, bytes)
		else
			print sprintf("EXISTS %d bytes\n".green, bytes)
		end
		fname
	end

	# collects all variants from all vcf files and executes the annotation and store procedures
	def populate(organism)
		orgname = organism.name.gsub(" ", "_")
		varidstore = "tmp/pfam_varids#{orgname}.bin"
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
			PfamAnnotation.log_info("Collecting coordinates from #{vcfids.size} vcf files".yellow)
			vcfids.each do |vcfid|
				vidx = VcfFileIndex.where(vcf_file_id: vcfid).first
				if vidx.nil?
					PfamAnnotation.log_warning("#{vcfid} has no index".magenta)
					next
				end
				vidx.each do |idxrecord|
					if varids[idxrecord[:variation_id]].nil?
						varids[idxrecord[:variation_id]] = %W(#{idxrecord[:chr]} #{idxrecord[:pos]} #{idxrecord[:variation_id]} #{idxrecord[:ref]} #{idxrecord[:alt]} 100 . VID=#{idxrecord[:variation_id]};VCFID=#{vcfid})
					end
				end
			end
			store_object(varids, varidstore)
		end
		PfamAnnotation.log_info("Collected #{varids.size} coordinates".yellow)
		PfamAnnotation.log_info("Processing slice...".yellow)
		varids.keys.each_slice(batch_size) do |vids|
			varcoords = vids.map{|vid| varids[vid]}
			annotate_coordinates(varcoords, organism)
			vids.each{|vid| varids.delete(vid) }
			# update variation id store
			PfamAnnotation.log_info("Updating #{varidstore}".magenta)
			store_object(varids, varidstore)
		end
		PfamAnnotation.log_info("DONE populating database with pfam".green)
		PfamAnnotation.log_info("Use bundle exec rake:activate[pfam] to run the annotation for all VCF files, making sure everyhting went smothly and is up to date.".green)
		PfamAnnotation.log_info("This command will also mark all VCF files to have been annotated with pfam".green)
	end

	def annotate_coordinates (varcoords, organism)
		vcf_file_dummy = VcfFile.new(name: "dummy_#{varcoords.object_id}", organism_id: organism.id)
		
		PfamAnnotation.log_info("-> Sorting #{varcoords.size} coordinates".yellow)
		sort_coordinates(varcoords)
		
		### generate VCF
		PfamAnnotation.log_info("-> Generating VCF file...".yellow)
		vcf = varcoords_to_vcf(varcoords, "tmp/ pfam _variations_#{Time.now.to_i.to_s(36)}.vcf")

		### use annotation class to annotate the variation vcf
		PfamAnnotation.log_info("-> Starting annotation".yellow)
		cka = PfamAnnotation.new()
		results = cka.perform_annotation(vcf.path, vcf_file_dummy)
		### store annotations
		cka_file = cka.store(results, vcf_file_dummy)
		raise "pfam annotation failed" unless cka_file.is_a?(TrueClass)
		PfamAnnotation.log_info("-> Annotation successfull".green)
		vcf.path
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

	def sort_coordinates(varcoords)
		chr_order = ((1..22).to_a + ["X", "Y", "M", "MT"])
		chr_order = Hash[chr_order.map {|x| [x.to_s, chr_order.index(x)]}]
		varcoords.sort! {|x, y|
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
	end

	def varcoords_to_vcf(varcoords, file_name)
		vcf = File.new(file_name, "w+")
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
		vcf
	end
end