namespace :vep do

	desc "Setup VEP."
	task :setup => :environment do |t, args|
		basedir = VepAnnotation.config("basedir")
		ensversion = VepAnnotation.config("ensembl_version")
		cachedir = VepAnnotation.config("cachedir")
		species = VepAnnotation.config("species")
		FileUtils.mkdir_p(basedir) if !Dir.exists?(basedir)
		FileUtils.mkdir_p(cachedir) if !Dir.exists?(cachedir)
		command = <<EOS
			# check for JSON setup
			(echo "use JSON;" | perl) 2>/dev/null
			if [ ! $? -eq 0 ];
			then
				echo "JSON perl library not found. Please install the perl module and make sure it is available for perl."
				echo "Test it with: (echo 'use JSON;' | perl) && echo SUCCESS"
				echo "When running ubuntu try:"
				echo "	sudo apt-get install libjson-perl"
				exit 1
			fi
			cd #{basedir}
			if [ ! -f #{ensversion}.zip ]; then
				wget https://github.com/Ensembl/ensembl-tools/archive/release/#{ensversion}.zip
				unzip #{ensversion}.zip
				mv -f ensembl-tools-release-#{ensversion}/scripts/variant_effect_predictor/* .
			else
				echo '#{ensversion}.zip already exists and will not be downloaded and unpacked. Delete the .zip to update VEP.'
			fi
			export PERL5LIB="$PERL5LIB:#{basedir}/:#{basedir}/htslib"
			export PATH="$PATH:#{basedir}/htslib"
			echo "YOUR PERL5LIB and PATH"
			echo "  PERL5LIB: $PERL5LIB"
			echo "  PATH: $PATH"
			echo "NOTE: To successfully download and install VEP you might need to install"
			echo "      the File::Copy::Recursive module "
			echo "          sudo cpan File::Copy::Recursive"
			echo "NOTE: To successfully compile HTSLIB you might need to install"
			echo "      the latest version of Module::Build using "
			echo "          sudo cpan Module::Build"
			perl INSTALL.pl -q -d #{basedir} -v #{ensversion} -c #{cachedir} -a a
EOS
#	yes "y" | perl INSTALL.pl -q -d #{basedir} -v #{ensversion} -c #{cachedir} -a cf -s homo_sapiens -y #{VepAnnotation.config("homo_sapiens_build")}
#	yes "y" | perl INSTALL.pl -q -d #{basedir} -v #{ensversion} -c #{cachedir} -a cf -s mus_musculus -y #{VepAnnotation.config("mus_musculus_build")}
		
		species.each do |name, build|
			load_cache = false
			if Dir.exists?(File.join(cachedir, name)) then
				STDOUT.puts "Cache at #{File.join(cachedir, name)} already exists. Download? [y/N]"
				resp = STDIN.gets.strip
				load_cache = true if (resp.downcase == "y")
			else
				load_cache = true
			end
			if (load_cache)
				command << "echo SETUP #{name} #{build}...\n"
				command << "perl INSTALL.pl -q -d #{basedir} -v #{ensversion} -c #{cachedir} -a cf -s #{name} #{(VepAnnotation.config("ensembl_version").to_i<=75)?"":"-y #{build}"}\n"
			end
		end
		STDOUT.puts "Convert VEP cache to use with tabix? [y/N]"
		STDOUT.puts "--> This is recommended as it greatly improves the cache performance."
		STDOUT.puts "--> Please make sure tabix is available for your system."
		resp = STDIN.gets.strip
		if resp.downcase == "y" then
			command << "echo Converting caches to used tabix for improved colocated variant retrieval\n"
			command << "perl convert_cache.pl --force_overwrite -d #{cachedir} -species all -version all\n"
		end
		system command
		create_script
	end
	
	desc "Setup VEP script."
	task :refresh_script => :environment  do |t, args|
		create_script
	end
	
	desc "Clear: Removes all annotations done with VEP"
	task :clear => :environment do
		print "Deleting all VEP annotations..."
		Vep.delete_all
		print "OK. DONE.\n"
	end
	
	desc "Clean VEP - remove VEP lib and caches"
	task :clean => :environment do
		basedir = VepAnnotation.config("basedir")
		cachedir = VepAnnotation.config("cachedir")
		
		STDOUT.puts "Do you want to delete #{basedir} and all of its content? [y/N]" 
		answer = STDIN.gets.strip
		FileUtils.rm_rf(basedir) if answer == "y"
		script_path = VepAnnotation.get_script
		FileUtils.rm(script_path) if answer == "y"
		STDOUT.puts "skipped" if answer != "y"
		
		if Dir.exists?(cachedir)
			STDOUT.puts "Do you want to delete #{cachedir} and all of its content? [y/N]" 
			answer = STDIN.gets.strip
			FileUtils.rm_rf(cachedir) if answer == "y"
			STDOUT.puts "skipped" if answer != "y"
			STDOUT.puts "DONE."
		else
			STDOUT.puts "Cache directory #{cachedir} does not exist (anymore?)."
		end
		
	end
	
	def create_script
		puts "create execution script"
		template_file = File.join(Rails.root, "extras", "snupy_again", "aqua", "annotations", "vep", "vep_script.sh.erb")
		puts "#{template_file}"
		template = File.open(template_file, "r").readlines().join("")
		script = ERB.new(template).result(binding)
		script_path = VepAnnotation.get_script 
		File.open(script_path, "w+"){|f|
			f.write(script)
		}
	end

end