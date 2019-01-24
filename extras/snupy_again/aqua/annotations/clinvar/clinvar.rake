namespace :clinvar do
	
	desc "Setup clinvar."
	task :setup => [:environment, :setup_clinvar_inst, :download_clinvar, :setup_dependencies, :check_tools] do |t, args|
		# 1 Break if Vcf already exists
		if !(ClinvarAnnotation.vcf_file.nil?) then
			print "ClinVar VCF already exists\n".green
			print "Do you want to remove it and setup again?[y/N]\n".cyan
			answer = STDIN.gets.strip.upcase
			if answer == "Y" then
				ClinvarAnnotation.vcf_file.destroy
				print "ClinvarAnnotation VCF destroyed. Remember to remove your annotations too.\n".cyan
			else
				exit 0
			end
			
		end
		
		# 2 Add the VCF file to the database
		# 2.1 Create a virtual institution to be used for this VCF file
		print "Adding ClinVar requires you to associate the ClinVar data with an institution\n".cyan
		print "You can either enter the name of an instituion or use SNuPy as your default institution\n".cyan
		print "---------------------------------------------------------------------------------------\n".cyan
		Institution.all.each_with_index do |inst, i|
			print " - #{inst.name}\n".white
		end
		print "---------------------------------------------------------------------------------------\n".cyan
		answer = STDIN.gets.strip
		answer = "ClinVar" if answer == ""
		inst = Institution.where(name: answer).first
		if (inst.nil?)
			print sprintf("#{answer} not found.\n".red)
			exit 1
		else
			print sprintf("Associating Clinvar dataset to #{answer}.\n".green)
		end
		# 2.1.1 Prompt user to use an existing or create a new one
		#
		vcfattrs = {
			name: File.basename(ClinvarAnnotation.local_vcf_file),
			contact: "",
			type: "VcfFileClinvar",
			institution_id: inst.id,
			organism_id: Aqua.organisms(:human),
			filename: File.basename(ClinvarAnnotation.local_vcf_file),
			md5checksum: nil,
			tags: [],
			status: :ADDVARIANTS
		}
		fin     = File.new(ClinvarAnnotation.local_vcf_file, "rb")
		vcfdata = VcfFile.upload2vcfdata(fin.read)
		fin.close()
		vcf_return = VcfFile.create_vcf_file(vcfattrs, vcfdata)
		vcf = nil
		if vcf_return[:created] then
			if vcf_return[:notice] == "OK" then
				if !vcf_return[:vcf_file].nil? then
					vcf = vcf_return[:vcf_file]
				end
			end
		end
		if vcf.nil? then
			print sprintf("ClinVar VCF could not be created in database.\n".red)
			print sprintf("#{vcf_return.pretty_inspect}.\n".red)
			raise "ClinVar VCF could not be created in database.\n".red
		else
			if (vcf.save) then
				print sprintf("ClinVar imported to database.\n".green)
				print sprintf("Please wait for the import of #{vcf.name} to finish".green)
			else
				print sprintf("ERRORS %s".red, vcf.errors.messages.to_s)
				raise "ClinVar VCF could not be saved.\n".red
			end
		end
	end

	desc "Remove: Removes all traces of clinvar"
	task :remove => :environment do
		print "OK. DONE.\n"
	end

	desc "Clear: Removes all annotations done with clinvar"
	task :clear => :environment do
		Clinvar.delete_all
		print "OK. DONE.\n"
	end
	
	desc "Clean clinvar - remove installation"
	task :clean => :environment do
		puts "Clear installation"
	end

	desc "Setup Dependencies clinvar"
	task :setup_dependencies do
		print "Setting up dependencies...".blue
		puts "DONE setting up dependencies.".blue
	end

	desc "Checks a list of tools"
	task :check_tools do
		%w(bash gzip tar).each do |cmd|
			check(cmd)
		end
	end
	
	desc "Download ClinVar VCF"
	task :download_clinvar do
		if !File.exists?(ClinvarAnnotation.local_vcf_file) then
			gzfile = ClinvarAnnotation.local_vcf_file +  ".gz"
			download(ClinvarAnnotation.config("vcf"), gzfile)
			print sprintf("Unzipping %s ...".blue, gzfile)
			success = ClinvarAnnotation.run("gunzip #{gzfile}")
			if (success)
				print sprintf("OK\n".green)
			else
				print sprintf("FAILED\n".red)
				raise "Unzipping #{gzfile} failed"
			end
		else
			print sprintf("%s already exists\n".green, ClinvarAnnotation.local_vcf_file)
		end
	end
	
	desc "Creates a placeholder institution named ClinVar"
	task :setup_clinvar_inst do
		inst = Institution.where(name: "ClinVar", email: "none@example.com").first
		if inst.nil? then
			inst = Institution.new(name: "ClinVar", email: "none@example.com")
			if (!inst.save) then
				print sprintf("FAILED TO CREATE CLINVAR INSTITUTION\n".red)
				raise "Failed to create ClinVar institution"
			else
				print sprintf("virtual ClinVar institution created\n".green)
			end
		else
			print sprintf("ClinVar institution already exists\n".green)
		end
	end
	
	desc "Populates the database with Capture Kit distances scores for all variations"
	task :populate => [:environment, :check_tools] do |t, args|
		populate(Aqua.organisms(:human))
	end

	def check(cmd)
		print "Checking #{cmd}..."
		tbxpath = ClinvarAnnotation.get_executable(cmd)
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
	
	# collects all variants from all vcf files and executes the annotation and store procedures
	def populate(organism)
		orgname = organism.name.gsub(" ", "_")
		varidstore = "tmp/clinvar_varids#{orgname}.bin"
		batch_size = 100000
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
			ClinvarAnnotation.log_info("Collecting coordinates from #{vcfids.size} vcf files".yellow)
			vcfids.each do |vcfid|
				vidx = VcfFileIndex.where(vcf_file_id: vcfid).first
				if vidx.nil?
					ClinvarAnnotation.log_warning("#{vcfid} has no index".magenta)
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
		ClinvarAnnotation.log_info("Collected #{varids.size} coordinates".yellow)
		ClinvarAnnotation.log_info("Processing slice...".yellow)
		varids.keys.each_slice(batch_size) do |vids|
			existing = Clinvar.where(variation_id: vids).select([:variation_id]).pluck(:variation_id)
			vids = vids.sort - existing.sort
			if vids.size == 0 then
				ClinvarAnnotation.log_info("The current slice has already been annotated. Skipping.".yellow)
				next
			end
			varcoords = vids.map{|vid| varids[vid]}
			annotate_coordinates(varcoords, organism)
			vids.each{|vid| varids.delete(vid) }
			# update variation id store
			ClinvarAnnotation.log_info("Updating #{varidstore}".magenta)
			store_object(varids, varidstore)
		end
		ClinvarAnnotation.log_info("DONE populating database with clinvar".green)
		ClinvarAnnotation.log_info("Use bundle exec rake:activate[clinvar] to run the annotation for all VCF files, making sure everyhting went smothly and is up to date.".green)
		ClinvarAnnotation.log_info("This command will also mark all VCF files to have been annotated with clinvar".green)
	end

	def annotate_coordinates (varcoords, organism)
		vcf_file_dummy = VcfFile.new(name: "dummy_#{varcoords.object_id}", organism_id: organism.id)
		
		ClinvarAnnotation.log_info("-> Sorting #{varcoords.size} coordinates".yellow)
		sort_coordinates(varcoords)
		
		### generate VCF
		ClinvarAnnotation.log_info("-> Generating VCF file...".yellow)
		vcf = varcoords_to_vcf(varcoords, "tmp/ clinvar _variations_#{Time.now.to_i.to_s(36)}.vcf")

		### use annotation class to annotate the variation vcf
		ClinvarAnnotation.log_info("-> Starting annotation".yellow)
		cka = ClinvarAnnotation.new()
		results = cka.perform_annotation(vcf.path, vcf_file_dummy)
		### store annotations
		cka_file = cka.store(results, vcf_file_dummy)
		raise "clinvar annotation failed" unless cka_file.is_a?(TrueClass)
		ClinvarAnnotation.log_info("-> Annotation successfull".green)
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