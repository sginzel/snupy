namespace :snp_eff do

	SNPEFFVERSION= SnpEffAnnotation.load_configuration_variable("snpeff_version")
	SNPEFFBASE= SnpEffAnnotation.load_configuration_variable("snpeffbase")
	SNPEFFLIB= SnpEffAnnotation.load_configuration_variable("snpeff_lib")
	SNPEFFJAR= SnpEffAnnotation.load_configuration_variable("snpeff_jar")
	SNPEFFCONFIG= SnpEffAnnotation.load_configuration_variable("snpeffconfig")
	HOMOSAPIENS= SnpEffAnnotation.load_configuration_variable("homo_sapiens_build")
	MUSMUSCULUS= SnpEffAnnotation.load_configuration_variable("mus_musculus_build")
	
	desc "Setup SnpEff."
	task :setup => :create_execution_template  do |t, args|
		puts "********** end: setup_SnpEff **********"
	end
	
	desc "Creates the SNPEff script execution script."
	task :refresh_script => :environment do |t, args|
		create_script
	end
	
	desc "Clear: Removes all annotations done with SnpEff"
	task :clear => :environment do
		print "Deleting all SnpEff annotations..."
		SnpEff.delete_all
		print "OK. DONE.\n"
	end

	desc "clean SnpEff tool- remove SnpEff lib and cache"
	task :clean=> :environment do
		puts "********** start: unsetup SnpEff **********"
		puts "Cleaning SnpEff Version: #{SNPEFFVERSION}"
		STDOUT.puts "Are you sure? (y/n)"
		input = STDIN.gets.strip
		if input == 'y'
			if Dir.exists?(SNPEFFBASE)
				sh "rm -r #{SNPEFFBASE}"
			end
			execute_script_path = File.join(Rails.root, "tmp", "aqua_snp_eff_exec.sh")
			if File.exists?(execute_script_path)
				puts "Removing execute script"
				sh "rm #{execute_script_path}"
			end
		else
			STDOUT.puts "unsetup aborted"
		end
		puts "********** end: unsetup SnpEff **********"
	end
	
	def create_script
		execute_file_template_path = File.join(Rails.root, "extras","snupy_again", "aqua", "annotations","snp_eff", "snp_eff_execute.sh.erb")
		puts "#{execute_file_template_path}"
		if File.exists?(execute_file_template_path)
			execute_file_template = File.open(execute_file_template_path, "r").readlines().join("")
			script = ERB.new(execute_file_template).result(binding)
			execute_script_path = File.join(Rails.root, "tmp", "aqua_snp_eff_exec.sh")
			script_file = execute_script_path
			File.open(script_file, "w+"){|f|
				f.write(script)
			}
		else
			raise  "aqua_snp_eff_exec.sh could not be created => #{execute_file_template_path} do not exist"
		end
		raise  "aqua_snp_eff_exec.sh could not be created" unless File.exists?script_file
	end
	
	desc "create execution script "
	task :create_execution_template => :manage_database  do
		puts "********** start: create execution script **********"
		puts "create execution template..."
		create_script
		puts "********** end: create execution script **********"
	end

	desc "manage database SnpEff tool"
	task :manage_database => :extract_snpeff do
		puts "********** start: manage_database **********"
		puts "downloading and installing SnpEff databases"
		puts "***** #{HOMOSAPIENS} *****"
		puts "SnpEff Version: #{SNPEFFVERSION}"

		if !Dir.exists?("snpEff/data/#{HOMOSAPIENS}") then
			puts "downloading and installin a pre-built SnpEff database HOMOSAPIENS #{HOMOSAPIENS}"
			sh "java -Xmx4g -jar #{SNPEFFJAR} download -c #{SNPEFFCONFIG} -v #{HOMOSAPIENS}"
		else
			puts "Noting to download for #{MUSMUSCULUS}"
		end

		puts "***** #{MUSMUSCULUS} *****"
		if !Dir.exists?("snpEff/data/#{MUSMUSCULUS}") then
			puts "downloading and installin a pre-built SnpEff database MUSMUSCULUS #{MUSMUSCULUS}"
			sh "java -Xmx4g -jar #{SNPEFFJAR} download -c #{SNPEFFCONFIG} -v #{MUSMUSCULUS}"
		else
			puts "Noting to download for #{MUSMUSCULUS}"
		end
		puts "********** end: manage_database **********"
	end

	desc "Extract SnpEff."
	task :extract_snpeff => :download_snpeff do
		puts "********** start: extract_SnpEff **********"
			sh "unzip #{SNPEFFLIB}/snpEff_v#{SNPEFFVERSION}_core.zip"
		puts "********** end: extract_SnpEff **********"
	end

	desc "Download SnpEff."
	task :download_snpeff => :setup_snpeff_dir do
		if File.exists?("#{SNPEFFLIB}/snpEff_v#{SNPEFFVERSION}_core.zip")
			puts "snpEff_v#{SNPEFFVERSION}_core.zip available."
		else
			puts "snpEff_v#{SNPEFFVERSION}_core.zip no available."
			path_snpEff_core = "#{SNPEFFLIB}/snpEff_v#{SNPEFFVERSION}_core.zip"
			url_snpEff_core = "http://sourceforge.net/projects/snpeff/files/snpEff_v#{SNPEFFVERSION}_core.zip"
			puts "Get Snp_Eff from #{url_snpEff_core}"
			sh "wget -O #{path_snpEff_core} #{url_snpEff_core}"
		end
		puts "********** end: setup_SnpEff **********"
	end

	desc "setup_dir"
	task :setup_snpeff_dir => :check_java do
		puts "********** start: set SnpEff directory **********"
		puts "Setting up SnpEff..."
		puts "set #{SNPEFFBASE}"
		if Dir.exists?(SNPEFFBASE)
			puts  "SNPEFFBASE available"
			cd  SNPEFFBASE
		else
			puts"SNPEFFBASE not available."
			mkdir_p SNPEFFBASE
			cd  SNPEFFBASE
		end
		puts "set #{SNPEFFLIB}"
		if  Dir.exists?(SNPEFFLIB)
			puts "SNPEFFLIB available"
			cd SNPEFFLIB
		else
			puts "SNPEFFLIB not available"
			puts SNPEFFLIB
			mkdir_p SNPEFFLIB
		end
		puts "********** end: set SnpEff directory **********"
	end

	desc "check jav version"
	task :check_java => :environment do
		puts "********** start: setup_snpeff **********"
		puts "********** start: check_java **********"
		puts "Checking java version..."
		# check exit status after command runs
		sh "java -version" do |ok, res|
			if ! ok then
				puts "JAVA not found (status = #{res.exitstatus})"
				puts "Please install JAVA Version > 1.7..."
				abort
			else
				val = %x[ #{"java -version"} 2>&1 >/dev/null ]
				abort "Please install JAVA Version > 1.7 ..." unless val.include?("1.7") || val.include?("1.8")
			end
		end
		puts "********** end: check_java **********"
	end

end