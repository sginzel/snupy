namespace :variant_effect_predictor do

	ENSEMBLVERSION = VariantEffectPredictorAnnotation.load_configuration_variable("ensembl_version")
	VEPBASE = VariantEffectPredictorAnnotation.load_configuration_variable("vepbase")
	VEPCACHE = VariantEffectPredictorAnnotation.load_configuration_variable("vep_cache")
	TOOL = VariantEffectPredictorAnnotation.load_configuration_variable("tool_version")
	ENSEMBLLIB = VariantEffectPredictorAnnotation.load_configuration_variable("ensembl_lib")
	PLUGINS = VariantEffectPredictorAnnotation.load_configuration_variable("plugins")
	HOMOSAPIENS = VariantEffectPredictorAnnotation.load_configuration_variable("homo_sapiens_build")
	MUSMUSCULUS = VariantEffectPredictorAnnotation.load_configuration_variable("mus_musculus_build")
	FASTA = VariantEffectPredictorAnnotation.load_configuration_variable("fasta_files")

	desc "Setup Variant Effect Predictor (VEP)."
	task :setup_dont_call_this => :create_execution_template do |t, args|
		puts "********** end: setup_vep **********"
	end

	desc "Creates the VEP script execution script."
	task :refresh_script => :environment do |t, args|
		create_script
	end

	desc "Clean VEP tool- remove vep lib and caches"
	task :clean=> :environment do
		puts "********** start: unsetup vep **********"
		puts "Unsetup VEP Version: #{ENSEMBLVERSION}"
		STDOUT.puts "Are you sure? (y/n)"
		input = STDIN.gets.strip
		if input == 'y'
			if Dir.exists?(VEPBASE)
				sh "rm -rf #{VEPBASE}"
			end
			execute_script_path = VariantEffectPredictorAnnotation.get_executable # File.join(Rails.root, "tmp", "aqua_vep_exec_#{ENSEMBLVERSION}_hs#{HOMOSAPIENS}_mm#{MUSMUSCULUS}.sh")
			if File.exists?(execute_script_path)
				puts "Removing execute script"
				sh "rm #{execute_script_path}"
			end
		else
			STDOUT.puts "unsetup aborted"
		end
		puts "********** end: unsetup vep **********"
	end

	desc "Clear: Removes all annotations done with Variant Effect Predictor"
	task :clear, [:tool] => :environment do |t, args|
		print "Deleting all VariationAnnotation..."
		VariationAnnotation.delete_all
		print "OK, Deleting all Consequences..."
		Consequence.delete_all
		ActiveRecord::Base.connection.execute("DELETE FROM variation_annotation_has_consequence")
		print "OK, Deleting all GeneticElement..."
		GeneticElement.delete_all
		print "OK, Deleting all LossOfFunction..."
		LossOfFunction.delete_all
		print "OK. DONE.\n"
	end

	def create_script
		puts "set execution template..."
		execute_file_template_path = File.join(Rails.root, "extras", "snupy_again", "aqua", "annotations", "variant_effect_predictor", "variant_effect_predictor_execute.sh.erb")
		puts "#{execute_file_template_path}"
		execute_file_template = File.open(execute_file_template_path, "r").readlines().join("")
		script = ERB.new(execute_file_template).result(binding)
		puts "create execution script..."
		execute_script_path = VariantEffectPredictorAnnotation.get_executable #File.join(Rails.root, "tmp", "aqua_vep_exec_#{ENSEMBLVERSION}_hs#{HOMOSAPIENS}_mm#{MUSMUSCULUS}.sh")
		File.open(execute_script_path, "w+"){|f|
			f.write(script)
		}
		raise  "#{execute_script_path} could not be created" unless File.exists?execute_script_path
	end

	desc "create execution template "
	task :create_execution_template  => :get_plugins do
		puts "********** start: create execution script **********"
		create_script
		puts "********** end: create execution template **********"
	end

	desc "get VEP plugins"
	task :get_plugins  => :extract_fasta_files  do
		puts "********** start: get_plugins **********"
		cd VEPCACHE
		if  Dir.exists? ("Plugins")
			puts "Plugins available."
		else
			puts "plugins not available."
			puts "downloading plugins..."
			url_VEP_plugins = "https://github.com/ensembl-variation/VEP_plugins"
			sh "git clone #{url_VEP_plugins}"

			puts "set plugins..."
			sh "mv VEP_plugins Plugins"

			cd ".."
			cd VEPBASE
		end
		puts "********** end: get_plugins **********"
	end
	
	desc "extract fasta files: homo_sapiens and mus_musculus"
	task :extract_fasta_files  => :get_fasta_files do
		homo_sapiens_path = "#{FASTA}/Homo_sapiens.GRCh#{HOMOSAPIENS}.#{ENSEMBLVERSION}.dna.primary_assembly.fa.gz"
		if File.exists?(homo_sapiens_path) then
			sh "gzip -d #{homo_sapiens_path}"
		end

		mus_musculus_path = "#{FASTA}/Mus_musculus.GRCm#{MUSMUSCULUS}.#{ENSEMBLVERSION}.dna.primary_assembly.fa.gz"
		if File.exists?(mus_musculus_path) then
			sh "gzip -d #{mus_musculus_path}"
		end
	end

	desc "get fasta files: homo_sapiens and mus_musculus"
	task :get_fasta_files  => :extract_VEP_species do
		homo_sapiens_path = "#{FASTA}/Homo_sapiens.GRCh#{HOMOSAPIENS}.#{ENSEMBLVERSION}.dna.primary_assembly.fa.gz"
		if File.exists?("#{FASTA}/Homo_sapiens.GRCh#{HOMOSAPIENS}.#{ENSEMBLVERSION}.dna.primary_assembly.fa") then
			puts "homo_sapiens fasta file available."
		else
			puts "Downloading homo_sapiens fasta files..."
			if ENSEMBLVERSION.to_i > 75 and HOMOSAPIENS.to_s == "37" then
				puts "WARNING Genome build 37 only exists for Ensembl version < 75 - we will use 75 for you."
				homo_sapiens_url = "ftp://ftp.ensembl.org/pub/release-75/fasta/homo_sapiens/dna/Homo_sapiens.GRCh#{HOMOSAPIENS}.75.dna.primary_assembly.fa.gz"
			else
				if ENSEMBLVERSION.to_i > 75 then
					homo_sapiens_url = "ftp://ftp.ensembl.org/pub/release-#{ENSEMBLVERSION}/fasta/homo_sapiens/dna/Homo_sapiens.GRCh#{HOMOSAPIENS}.dna.primary_assembly.fa.gz"
				else
					homo_sapiens_url = "ftp://ftp.ensembl.org/pub/release-#{ENSEMBLVERSION}/fasta/homo_sapiens/dna/Homo_sapiens.GRCh#{HOMOSAPIENS}.#{ENSEMBLVERSION}.dna.primary_assembly.fa.gz"
				end
			end
			puts "#{homo_sapiens_url} => #{homo_sapiens_path}"
			sh "wget -nv -O #{homo_sapiens_path} #{homo_sapiens_url}"
		end

		mus_musculus_path = "#{FASTA}/Mus_musculus.GRCm#{MUSMUSCULUS}.#{ENSEMBLVERSION}.dna.primary_assembly.fa.gz"
		if File.exists?("#{FASTA}/Mus_musculus.GRCm#{MUSMUSCULUS}.#{ENSEMBLVERSION}.dna.primary_assembly.fa") then
			puts "mus musculus fasta file available."
		else
			puts "Downloading mus musculus fasta files..."
			if ENSEMBLVERSION.to_i > 75 then
				mus_musculus_url = "ftp://ftp.ensembl.org/pub/release-#{ENSEMBLVERSION}/fasta/mus_musculus/dna/Mus_musculus.GRCm#{MUSMUSCULUS}.dna.primary_assembly.fa.gz"
			else
				mus_musculus_url = "ftp://ftp.ensembl.org/pub/release-#{ENSEMBLVERSION}/fasta/mus_musculus/dna/Mus_musculus.GRCm#{MUSMUSCULUS}.#{ENSEMBLVERSION}.dna.primary_assembly.fa.gz"
			end
			puts "#{mus_musculus_url} => #{mus_musculus_path}"
			sh "wget -nv -O #{mus_musculus_path}  #{mus_musculus_url}"
		end
	end

	desc "extract_VEP_species: homo_sapiens and mus_musculus"
	task :extract_VEP_species  => :download_vep_species do
		puts "********** start: extract_VEP_species **********"

		puts "extract homo_sapiens_vep"
		path_homo_sapiens_vep = "#{VEPCACHE}/homo_sapiens_vep_#{ENSEMBLVERSION}_GRCh#{HOMOSAPIENS}.tar.gz"
		path_homo_sapiens_cache = "#{VEPCACHE}/homo_sapiens/#{ENSEMBLVERSION}_GRCh#{HOMOSAPIENS}/"
		if !Dir.exists?(path_homo_sapiens_cache) then
			sh "tar -xzf #{path_homo_sapiens_vep}  -C #{VEPCACHE}"
			# sh "rm #{path_homo_sapiens_vep}"
		else
			puts "Homo sapiens cachedir exists: #{path_homo_sapiens_cache}"
		end

		puts "extract mus_musculus_vep"
		path_mus_musculus_vep = "#{VEPCACHE}/mus_musculus_vep#{ENSEMBLVERSION}_GRCm#{MUSMUSCULUS}.tar.gz"
		path_mus_musculus_cache = "#{VEPCACHE}/mus_musculus/#{ENSEMBLVERSION}_GRCm#{MUSMUSCULUS}/"
		if !File.exists?(path_mus_musculus_cache) then
			sh "tar -xzf #{path_mus_musculus_vep} -C #{VEPCACHE}"
		# sh "rm #{path_mus_musculus_vep}"
		else
			puts "Mus musculus cachedir exists: #{path_mus_musculus_cache}"
		end
		
		tabix = `which tabix 2>/dev/null`.to_s.strip
		if not tabix == "" then
			puts "We found tabix on your system. Will improve VEP cache using tabix"
			convert_script = "#{VariantEffectPredictorAnnotation.load_configuration_variable("ensembl_lib")}/ensembl-tools/scripts/variant_effect_predictor/convert_cache.pl"
			ensembllib = VariantEffectPredictorAnnotation.load_configuration_variable("ensembl_lib")
			hscmd = "perl #{convert_script} -species homo_sapiens -version #{ENSEMBLVERSION}_GRCh#{HOMOSAPIENS} -tabix #{tabix} -dir #{VEPCACHE}"
			mmcmd = "perl #{convert_script} -species mus_musculus -version #{ENSEMBLVERSION}_GRCm#{MUSMUSCULUS} -tabix #{tabix} -dir #{VEPCACHE}"
			hscmd = "echo homo sapiens cache was already processed with tabix" if File.exists?(File.join(path_homo_sapiens_cache, "1", "all_vars.gz.tbi"))
			hscmd = "echo mus muculus cache was already processed with tabix" if File.exists?(File.join(path_mus_musculus_cache, "1", "all_vars.gz.tbi"))
			system <<EOS
			ENSEMBLLIB="#{ensembllib}"
			PERL5LIB="${PERL5LIB}:$ENSEMBLLIB/bioperl-1.6.1"
			PERL5LIB="${PERL5LIB}:$ENSEMBLLIB/BioPerl-1.6.1"
			PERL5LIB="${PERL5LIB}:$ENSEMBLLIB/ensembl/modules"
			PERL5LIB="${PERL5LIB}:$ENSEMBLLIB/ensembl-compara/modules"
			PERL5LIB="${PERL5LIB}:$ENSEMBLLIB/ensembl-variation/modules"
			PERL5LIB="${PERL5LIB}:$ENSEMBLLIB/ensembl-funcgen/modules"
			export PERL5LIB
			#{hscmd}
			#{mmcmd}
EOS
		end
		
		puts "********** end: extract_VEP_species **********"
	end

	desc "download_VEP_species:  homo_sapiens and mus_musculus"
	task :download_vep_species  => :extract_bioperl do
		puts "********** start: download_vep_species **********"

		puts "homo_sapiens cache..."
		path_homo_sapiens = "#{VEPCACHE}/homo_sapiens_vep_#{ENSEMBLVERSION}_GRCh#{HOMOSAPIENS}.tar.gz"
		if  Dir.exists? ("#{VEPCACHE}/homo_sapiens/#{ENSEMBLVERSION}")
			puts "homo_sapiens data available."
		else
			if ENSEMBLVERSION.to_i > 75 then
				url_homo_sapiens= "ftp://ftp.ensembl.org/pub/release-#{ENSEMBLVERSION}/variation/VEP/homo_sapiens_vep_#{ENSEMBLVERSION}_GRCh#{HOMOSAPIENS}.tar.gz"
			else
				url_homo_sapiens= "ftp://ftp.ensembl.org/pub/release-#{ENSEMBLVERSION}/variation/VEP/homo_sapiens_vep_#{ENSEMBLVERSION}.tar.gz"
			end
			puts "get homo_sapiens cache #{url_homo_sapiens} => #{path_homo_sapiens}" unless File.exist?(path_homo_sapiens)
			sh "wget -nv -O #{path_homo_sapiens}  #{url_homo_sapiens}" unless File.exist?(path_homo_sapiens)
		end
		puts "mus musculus cache..."
		path_mus_musculus = "#{VEPCACHE}/mus_musculus_vep#{ENSEMBLVERSION}_GRCm#{MUSMUSCULUS}.tar.gz"
		if Dir.exists?("#{VEPCACHE}/mus_musculus/#{ENSEMBLVERSION}")
			puts "mus_musculus available."
		else
			if ENSEMBLVERSION.to_i > 75 then
				url_mus_musculus = "ftp://ftp.ensembl.org/pub/release-#{ENSEMBLVERSION}/variation/VEP/mus_musculus_vep_#{ENSEMBLVERSION}_GRCm#{MUSMUSCULUS}.tar.gz"
			else
				url_mus_musculus = "ftp://ftp.ensembl.org/pub/release-#{ENSEMBLVERSION}/variation/VEP/mus_musculus_vep_#{ENSEMBLVERSION}.tar.gz"
			end
			puts "get mus_musculus cache #{url_mus_musculus } => #{path_mus_musculus}" unless File.exist?(path_mus_musculus)
			sh "wget -nv -O #{path_mus_musculus} #{url_mus_musculus}" unless File.exist?(path_mus_musculus)
		end
		puts "********** end: download_vep_species **********"
	end

	desc "extract bioperl"
	task :extract_bioperl => :download_ensembl do
		puts "********** start: extract ensembl **********"
		bio_perl_path = "#{ENSEMBLLIB}/BioPerl-1.6.1.tar.gz"
		if File.exists?(bio_perl_path)
			puts "extracting bioperl...(#{bio_perl_path})"
			puts "  to #{ENSEMBLLIB} from #{`pwd`}"
			olddir = `pwd`.strip
			cd ENSEMBLLIB
			sh "tar -zxf #{bio_perl_path}"
			cd olddir
		# sh "rm #{bio_perl_path}"
		else
			puts "bioperl not downloaded"
		end
		puts "********** end: extract_ensembl **********"
	end

	desc "Download ensembl cache"
	task :download_ensembl  =>  :setup_dir do
		puts "********** start: download_ensembl **********"

		git_version = `git --version`.strip.split(" ")
		abort("Please install git.") unless git_version[0] == "git"
		git_version = git_version[2]

		if (Gem::Version.new(git_version) >= Gem::Version.new("1.7.10")) then
			gitcall = "git clone -b release/#{ENSEMBLVERSION} --single-branch"
		else
			gitcall = "git clone -b release/#{ENSEMBLVERSION}"
		end

		if Dir.exists?("#{ENSEMBLLIB}/ensembl")
			puts "ensembl.tar.gz available."
		else
			puts "ensembl.tar.gz nicht available."
			puts  "Get ensembl..."
			cd ENSEMBLLIB
			sh "#{gitcall} git://github.com/Ensembl/ensembl.git"
		end

		if Dir.exists?("#{ENSEMBLLIB}/ensembl-compara")
			puts "ensembl-compara.tar.gz available."
		else
			puts "ensembl-compara.tar.gz nicht available."
			puts "Get compara..."
			cd ENSEMBLLIB
			sh "#{gitcall} git://github.com/Ensembl/ensembl-compara.git"

		end

		if Dir.exists?("#{ENSEMBLLIB}/ensembl-variation")
			puts "ensembl-variation.tar.gz available."
		else
			puts "ensembl-variation.tar.gz nicht available."
			puts "Get variation..."
			cd ENSEMBLLIB
			sh "#{gitcall} git://github.com/Ensembl/ensembl-variation.git"

		end

		if Dir.exists?("#{ENSEMBLLIB}/ensembl-funcgen")
			puts "ensembl-functgenomics.tar.gz available."
		else
			puts "ensembl-functgenomics nicht available."
			puts "Get functgenomics..."
			cd ENSEMBLLIB
			sh "#{gitcall} git://github.com/Ensembl/ensembl-funcgen.git"
		end

		if Dir.exists?("#{ENSEMBLLIB}/ensembl-tools") then
			puts "VEP script available."
		else
			puts "get specific version of VEP script"
			cd ENSEMBLLIB
			sh "#{gitcall}  git://github.com/Ensembl/ensembl-tools.git"

		end

		#bioperl
		bio_perl_path = "#{ENSEMBLLIB}/BioPerl-1.6.1"
		if Dir.exists?(bio_perl_path)
			puts "BioPerl-1.6.1 available."
		else
			url_bioperl = "http://bioperl.org/DIST/BioPerl-1.6.1.tar.gz"
			puts "BioPerl-1.6.1 not available - downloading #{url_bioperl}"
			sh "wget -nv -O #{ENSEMBLLIB}/BioPerl-1.6.1.tar.gz #{url_bioperl}"
		end

		puts "********** end: Download ensembl **********"
	end

	desc "setup_dir"
	task :setup_dir => :environment do
		puts "********** start: setup_vep **********"
		puts "Setting up Variant Effect Predictor(VEP)..."

		puts "Create the setup and execution script for VEP and execute the setup if neccessary..."

		puts "********** start: set VEP directory **********"
		puts "set #{VEPBASE}"
		if  Dir.exists?(VEPBASE)
			puts  "VEPBASE directory available"
			cd  VEPBASE
		else
			puts"VEPBASE directory not available - creating."
			mkdir_p VEPBASE
			cd  VEPBASE
		end

		puts "set #{TOOL}"
		if  Dir.exists?(TOOL)
			puts "version directory available"
			cd  TOOL
		else
			puts "version directory not available - creating."
			mkdir_p TOOL
		end

		puts "set #{ENSEMBLLIB}"
		if  Dir.exists?(ENSEMBLLIB)
			puts "ENSEMBLLIB available"
			cd ENSEMBLLIB
		else
			puts "ENSEMBLLIB directory not available - creating."
			puts ENSEMBLLIB
			mkdir_p ENSEMBLLIB
		end

		puts "set #{VEPCACHE}"
		if  Dir.exists?(VEPCACHE)
			puts "VEPCACHE available"
			cd VEPCACHE
		else
			puts "VEPCACHE directory not available - creating."
			puts VEPCACHE
			mkdir_p VEPCACHE
		end

		puts "set #{FASTA}"
		if  Dir.exists?(FASTA)
			puts "FASTA directory available"
			cd FASTA
		else
			puts "FASTA directory not available - creating."
			puts FASTA
			mkdir_p FASTA
		end
		puts "********** end: set VEP directory **********"
	end
end
