namespace :annovar do

	ANNOVARVERSION= AnnovarAnnotation.load_configuration_variable("annovar_version")
	ANNOVARBASE= AnnovarAnnotation.load_configuration_variable("annovar_base")
	ANNOVARLIB= AnnovarAnnotation.load_configuration_variable("annovar_lib")
	HOMOSAPIENSBUILD= AnnovarAnnotation.load_configuration_variable("homo_sapiens_build")
	HOMOSAPIENSDB= AnnovarAnnotation.load_configuration_variable("annovar_cache_homo_sapiens")
	MUSMUSCULUSBUILD= AnnovarAnnotation.load_configuration_variable("mus_musculus_build")
	MUSMUSCULUSDB= AnnovarAnnotation.load_configuration_variable("annovar_cache_mus_musculus")
	SCRIPT= AnnovarAnnotation.load_configuration_variable("annovar_script")
	SCRIPTRETRIEVESEQFROMFASTA= AnnovarAnnotation.load_configuration_variable("annovar_retrieve_seq_from_fasta_script")
	
	desc "Setup ANNOVAR."
	task :setup => :create_execution_template  do |t, args|
		puts "********** end: setup_annovar **********"
	end
	
	desc "Setup ANNOVAR script."
	task :refresh_script => :environment  do |t, args|
		create_shell_script
		puts "********** end: refresh script **********"
	end
	
#	desc "Parse the output of a ANNOVAR file"
#	task :parse, [:file] => :environment  do |t, args|
#		annovar = AnnovarAnnotation.new()
#		annovar.parse(args[:file], VcfFile.find(1))
#		puts "********** end: parse file **********"
#	end
	
	
	desc "Clear: Removes all annotations done with Annovar"
	task :clear => :environment do
		print "Deleting all Annovar annotations..."
		Annovar.delete_all
		print "OK. DONE.\n"
	end
	
	desc "Clean ANNOVAR tool - remove ANNOVAR lib and caches"
	task :clean => :environment do
		puts "********** start: clean ANNOVAR **********"
		puts "Remove ANNOVAR Version: #{ANNOVARVERSION}"
		STDOUT.puts "Are you sure? (y/n)"
		input = STDIN.gets.strip
		if input == 'y'
			if Dir.exists?(ANNOVARBASE)
				sh "rm -r #{ANNOVARBASE}"
			end
			execute_script_path = File.join(Rails.root, "tmp", "aqua_annovar_exec.sh")
			if File.exists?(execute_script_path)
				puts "Removing execute script"
				sh "rm #{execute_script_path}"
			end
		else
			STDOUT.puts "clean aborted"
		end
		puts "********** end: clean ANNOVAR **********"
	end
	
	def create_shell_script
		execute_file_template_path = File.join(Rails.root, "extras","snupy_again", "aqua", "annotations","annovar", "annovar_execute.sh.erb")
		puts "#{execute_file_template_path}"
		if File.exists?(execute_file_template_path)
			execute_file_template = File.open(execute_file_template_path, "r").readlines().join("")
			script = ERB.new(execute_file_template).result(binding)
			execute_script_path = File.join(Rails.root, "tmp", "aqua_annovar_exec.sh")
			script_file = execute_script_path
			File.open(script_file, "w+"){|f|
				f.write(script)
			}
		else
			raise "aqua_annovar_exec.sh could not be created => #{execute_file_template_path} does not exist"
		end
		raise "aqua_annovar_exec.sh could not be created" unless File.exists?script_file
	end
	
	desc "create execution script "
	task :create_execution_template => :manage_databases_musmusculus_gene_based do
		puts "********** start: create execution script **********"
		puts "create execution template..."
		create_shell_script()
		puts "********** end: create execution script **********"
	end

	desc "Mus Musculus databases for gene-based annovar annotation"
	task :manage_databases_musmusculus_gene_based => :manage_databases_gene_based do
		puts "********** start: manage_databases_musmusculus_gene_based **********"
		puts "Downloading and installing ANNOVAR #{ANNOVARVERSION} databases for MUSMUSCULUS #{MUSMUSCULUSBUILD}"
		puts "Setting mouse mm9 directory..."
		if Dir.exists?("#{MUSMUSCULUSDB}/mm9_seq")then
			puts "Mouse mm9_seq directory available."
		else
			puts "Mouse mm9_seq directory not available: setting #{MUSMUSCULUSDB}/#{MUSMUSCULUSBUILD}_seq..."
			mkdir_p "#{MUSMUSCULUSDB}/mm9_seq"
		end

		mm9_path_chromFa= "#{MUSMUSCULUSDB}/#{MUSMUSCULUSBUILD}_seq/chromFa.tar.gz"
		puts "Downloading annotation database..."
		if File.exists?("#{MUSMUSCULUSDB}/#{MUSMUSCULUSBUILD}_seq/chromFa.tar.gz")then
			puts "chromFa available."
			sh "tar -xzf #{mm9_path_chromFa} -C #{MUSMUSCULUSDB}/#{MUSMUSCULUSBUILD}_seq/"
			#sh "rm #{mm9_path_chromFa}"
		else
			mm9_url_chromFa= "ftp://hgdownload.cse.ucsc.edu/goldenPath/#{MUSMUSCULUSBUILD}/bigZips/chromFa.tar.gz"
			sh "wget -O #{mm9_path_chromFa} #{mm9_url_chromFa}" do |ok, res|
				if ! ok then
					puts "chromFa: Mouse mm9 ensGene setup failed (status = #{res.exitstatus})"
					abort
				end
			end
		end

		mm9_path_chromAgp= "#{MUSMUSCULUSDB}/#{MUSMUSCULUSBUILD}_seq/chromAgp.tar.gz"
		if File.exists?("#{MUSMUSCULUSDB}/#{MUSMUSCULUSBUILD}_seq/chromAgp.tar.gz")then
			puts "chromAgp available."
			sh "tar -xzf #{mm9_path_chromAgp} -C #{MUSMUSCULUSDB}/#{MUSMUSCULUSBUILD}_seq/"
			#sh "rm #{mm9_path_chromAgp}"
		else
			mm9_url_chromAgp= "ftp://hgdownload.cse.ucsc.edu/goldenPath/#{MUSMUSCULUSBUILD}/bigZips/chromAgp.tar.gz"
			sh "wget -O #{mm9_path_chromAgp} #{mm9_url_chromAgp}" do |ok, res|
				if ! ok then
					puts "chromAgp: Mouse mm9 ensGene setup failed (status = #{res.exitstatus})"
					abort
				end
			end
		end

		mm9_path_chromOut= "#{MUSMUSCULUSDB}/#{MUSMUSCULUSBUILD}_seq/chromOut.tar.gz"
		if File.exists?("#{MUSMUSCULUSDB}/#{MUSMUSCULUSBUILD}_seq/chromOut.tar.gz")then
			puts "chromOut available."
			sh "tar -xzf #{mm9_path_chromOut} -C #{MUSMUSCULUSDB}/#{MUSMUSCULUSBUILD}_seq/"
			#sh "rm #{mm9_path_chromOut}"
		else
			mm9_url_chromOut= "ftp://hgdownload.cse.ucsc.edu/goldenPath/#{MUSMUSCULUSBUILD}/bigZips/chromOut.tar.gz"
			sh "wget -O #{mm9_path_chromOut} #{mm9_url_chromOut}" do |ok, res|
				if ! ok then
					puts "chromOut: Mouse mm9 ensGene setup failed (status = #{res.exitstatus})"
					abort
				end
			end
		end

		mm9_path_chromTrf= "#{MUSMUSCULUSDB}/#{MUSMUSCULUSBUILD}_seq/chromTrf.tar.gz"
		if File.exists?("#{MUSMUSCULUSDB}/#{MUSMUSCULUSBUILD}_seq/chromTrf.tar.gz")then
			puts "chromTrf available."
			sh "tar -xzf #{mm9_path_chromTrf} -C #{MUSMUSCULUSDB}/#{MUSMUSCULUSBUILD}_seq/"
			#sh "rm #{mm9_path_chromTrf}"
		else

			mm9_url_chromTrf= "ftp://hgdownload.cse.ucsc.edu/goldenPath/#{MUSMUSCULUSBUILD}/bigZips/chromTrf.tar.gz"
			sh "wget -O #{mm9_path_chromTrf} #{mm9_url_chromTrf}" do |ok, res|
				if ! ok then
					puts "chromTrf: Mouse mm9 ensGene setup failed (status = #{res.exitstatus})"
					abort
				end
			end
		end

		puts "Downloading ensGene..."
		if File.exists?("#{MUSMUSCULUSDB}/#{MUSMUSCULUSBUILD}_ensGene.txt")then
			puts "ensGene available."
		else
			sh "perl #{SCRIPT} -buildver #{MUSMUSCULUSBUILD} -downdb ensGene #{MUSMUSCULUSDB}" do |ok, res|
				if ! ok then
					puts " Mouse mm9 ensGene setup failed (status = #{res.exitstatus})"
					abort
				end
			end
		end

		#retrieve_seq_from_fasta.pl annovar/mousedb/mm9_ensGene.txt -seqdir annovar/mousedb/mm9_seq -format ensGene -outfile annovar/mousedb/mm9_ensGeneMrna.fa
		if File.exists?("#{MUSMUSCULUSDB}/#{MUSMUSCULUSBUILD}_ensGeneMrna.fa") then
			puts "Mouse mm9 FASTA_ensGeneMrna.fa available."
		else
			sh "perl #{SCRIPTRETRIEVESEQFROMFASTA} #{MUSMUSCULUSDB}/#{MUSMUSCULUSBUILD}_ensGene.txt -seqdir #{MUSMUSCULUSDB}/#{MUSMUSCULUSBUILD}_seq -format ensGene -outfile #{MUSMUSCULUSDB}/#{MUSMUSCULUSBUILD}_ensGeneMrna.fa" do |ok, res|
				if ! ok then
					puts "Mouse mm9 FASTA_refGeneMrna.fa setup failed (status = #{res.exitstatus})"
					abort
				end
			end
		end
		puts "Downloading refSeq..."
		if File.exists?("#{MUSMUSCULUSDB}/#{MUSMUSCULUSBUILD}_refGene.txt")then
			puts "refGene available."
		else
			sh "perl #{SCRIPT} -buildver #{MUSMUSCULUSBUILD} -downdb refGene #{MUSMUSCULUSDB}" do |ok, res|
				if ! ok then
					puts " Mouse mm9 refGene setup failed (status = #{res.exitstatus})"
					abort
				end
			end
		end
		#retrieve_seq_from_fasta.pl mousedb/mm9_refGene.txt -seqdir /annovar/mousedb/mm9_seq -format refGene -outfile mousedb/mm9_refGeneMrna.fa
		if File.exists?("#{MUSMUSCULUSDB}/mm9_refGeneMrna.fa") then
			puts "Mouse mm9 FASTA_refGeneMrna.fa available."
		else
			sh "perl #{SCRIPTRETRIEVESEQFROMFASTA} #{MUSMUSCULUSDB}/mm9_refGene.txt -seqdir #{MUSMUSCULUSDB}/mm9_seq -format refGene -outfile #{MUSMUSCULUSDB}/mm9_refGeneMrna.fa" do |ok, res|
				if ! ok then
					puts "Mouse refGene setup failed (status = #{res.exitstatus})"
					abort
				end
			end
		end
		puts "********** end: manage_databases_musmusculus_gene_based **********"
	end
	desc "Databases for gene-based annovar annotation"
	task :manage_databases_gene_based => :manage_databases_region_based  do
		puts "********** start: manage_databases_gene_based **********"
		puts "Downloading and installing ANNOVAR #{ANNOVARVERSION} databases for HOMOSAPIENS #{HOMOSAPIENSBUILD}..."

		puts "Downloading Ensembl  ..."
		if File.exists?("#{HOMOSAPIENSDB}/#{HOMOSAPIENSBUILD}_ensGene.txt")then
			puts "ensGene available."
		else
			sh "perl #{SCRIPT} -downdb -buildver #{HOMOSAPIENSBUILD} -webfrom annovar ensGene #{HOMOSAPIENSDB}" do |ok, res|
				if ! ok then
					puts "wgRna setup failed (status = #{res.exitstatus})"
					abort
				end
			end
		end
		puts "Downloading UCSC Known Gene  ..."
		if File.exists?("#{HOMOSAPIENSDB}/#{HOMOSAPIENSBUILD}_knownGene.txt")then
			puts "knownGene available."
		else
			sh "perl #{SCRIPT} -downdb -buildver #{HOMOSAPIENSBUILD} -webfrom annovar knownGene #{HOMOSAPIENSDB}" do |ok, res|
				if ! ok then
					puts "knownGene setup failed (status = #{res.exitstatus})"
					abort
				end
			end
		end
		puts "********** end: manage_databases_gene_based **********"
	end

	desc "manage databases for region-based annovar annotation"
	task :manage_databases_region_based => :manage_databases_filter_based do
		puts "********** start: manage_databases_region-based **********"
		puts "Downloading and installing ANNOVAR #{ANNOVARVERSION} databases for HOMOSAPIENS #{HOMOSAPIENSBUILD}..."

		#wgRna:Identify variants disrupting microRNAs and snoRNAs
		#annotate_variation.pl -build hg19 -downdb wgRna humandb/
		#annotate_variation.pl -regionanno -build hg19 -out ex1 -dbtype wgRna example/ex1.avinput humandb/
		puts "Downloading wgRna..."
		if File.exists?("#{HOMOSAPIENSDB}/#{HOMOSAPIENSBUILD}_wgRna.txt")then
			puts "wgRna available."
		else
			sh "perl #{SCRIPT} -build #{HOMOSAPIENSBUILD} -downdb  wgRna #{HOMOSAPIENSDB}" do |ok, res|
				if ! ok then
					puts "wgRna setup failed (status = #{res.exitstatus})"
					abort
				end
			end
		end
		#TargetScanS: Identify variants disrupting predicted microRNA binding sites
		#annotate_variation.pl -build hg19 -downdb targetScanS humandb/
		#annotate_variation.pl -regionanno -build hg19 -out ex1 -dbtype targetScanS example/ex1.avinput humandb/
		puts "Downloading targetScanS..."
		if File.exists?("#{HOMOSAPIENSDB}/#{HOMOSAPIENSBUILD}_targetScanS.txt")then
			puts "wtargetScanS available."
		else
			sh "perl #{SCRIPT} -build #{HOMOSAPIENSBUILD} -downdb targetScanS #{HOMOSAPIENSDB}" do |ok, res|
				if ! ok then
					puts "targetScanS setup failed (status = #{res.exitstatus})"
					abort
				end
			end
		end
		#tfbsConsSites: Transcription factor binding site annotation
		#annotate_variation.pl -build hg19 -downdb tfbsConsSites humandb/
		#annotate_variation.pl -regionanno -build hg19 -out ex1 -dbtype tfbsConsSites example/ex1.avinput humandb/
		puts "Downloading tfbsConsSites..."
		if File.exists?("#{HOMOSAPIENSDB}/#{HOMOSAPIENSBUILD}_tfbsConsSites.txt")then
			puts "tfbsConsSites available."
		else
			sh "perl #{SCRIPT}  -build  #{HOMOSAPIENSBUILD} -downdb tfbsConsSites #{HOMOSAPIENSDB}" do |ok, res|
				if ! ok then
					puts "tfbsConsSites setup failed (status = #{res.exitstatus})"
					abort
				end
			end
		end

		#genomicSuperDups: Identify variants located in segmental duplications
		#annotate_variation.pl -build hg19 -downdb genomicSuperDups humandb/
		#annotate_variation.pl -regionanno -build hg19 -out ex1 -dbtype genomicSuperDups example/ex1.avinput humandb/
		puts "Downloading genomicSuperDups..."
		if File.exists?("#{HOMOSAPIENSDB}/#{HOMOSAPIENSBUILD}_genomicSuperDups.txt")then
			puts "genomicSuperDups available."
		else
			sh "perl #{SCRIPT}  -build  #{HOMOSAPIENSBUILD}  -downdb genomicSuperDups #{HOMOSAPIENSDB}" do |ok, res|
				if ! ok then
					puts "genomicSuperDups setup failed (status = #{res.exitstatus})"
					abort
				end
			end
		end

		#GWAS: Identify variants reported in previously published GWAS
		#annotate_variation.pl -build hg19 -downdb gwasCatalog humandb/
		#annotate_variation.pl -regionanno -build hg19 -out ex1 -dbtype gwasCatalog example/ex1.avinput humandb/
		puts "Downloading GWAS..."
		if File.exists?("#{HOMOSAPIENSDB}/#{HOMOSAPIENSBUILD}_gwasCatalog.txt")then
			puts "GWAS available."
		else
			sh "perl #{SCRIPT}  -build  #{HOMOSAPIENSBUILD}  -downdb gwasCatalog #{HOMOSAPIENSDB}" do |ok, res|
				if ! ok then
					puts "GWAS setup failed (status = #{res.exitstatus})"
					abort
				end
			end
		end
		puts "********** end: manage_databases_region_based **********"
	end
	desc "manage databases for filter-based annovar annotation"
	task :manage_databases_filter_based => :extract_annovar do
		puts "********** start: manage_databases_filter_based **********"
		puts "Downloading and installing ANNOVAR #{ANNOVARVERSION} databases for HOMOSAPIENS #{HOMOSAPIENSBUILD}..."

		#ljb26
		puts "Downloading ljb26..."
		if File.exists?("#{HOMOSAPIENSDB}/hg19_ljb26_all.txt")then
			puts "ljb26 available."
		else
			sh "perl #{SCRIPT} -buildver #{HOMOSAPIENSBUILD} -downdb -webfrom annovar ljb26_all #{HOMOSAPIENSDB}" do |ok, res|
				if ! ok then
					puts "ljb26 setup failed (status = #{res.exitstatus})"
					abort
				end
			end
		end

		#GENOMEPROJECTS 2014
		puts "Downloading GENOMEPROJECTS 2014..."
		if File.exists?("#{HOMOSAPIENSDB}/#{HOMOSAPIENSBUILD}_ALL.sites.2014_10.txt")then
			puts "10000 Genome Projects 2014 available."
		else
			sh "perl #{SCRIPT} -buildver #{HOMOSAPIENSBUILD} -downdb  -webfrom annovar 1000g2014oct #{HOMOSAPIENSDB}" do |ok, res|
				if ! ok then
					puts "10000 Genome Projects 2014 setup failed (status = #{res.exitstatus})"
					abort
				end
			end
		end

		#dbSNP annotations
		puts "Downloading dbSNP..."
		#annotate_variation.pl -downdb -buildver hg19 -webfrom annovar snp138 humandb
		#annotate_variation.pl -filter -out ex1 -build hg19 -dbtype snp138 example/ex1.avinput humandb/
		#annotate_variation.pl -filter -dbtype ljb23_all -buildver hg19 -out ex1 example/ex1.avinput humandb/
		if File.exists?("#{HOMOSAPIENSDB}/#{HOMOSAPIENSBUILD}_snp138.txt")then
			puts "dbSNP available."
		else
			sh "perl #{SCRIPT} -buildver #{HOMOSAPIENSBUILD} -downdb -webfrom annovar snp138 #{HOMOSAPIENSDB}" do |ok, res|
				if ! ok then
					puts "dbSNP setup failed (status = #{res.exitstatus})"
					abort
				end
			end
		end

		#ESP (exome sequencing project) annotations
		puts "Downloading ESP..."
		#annotate_variation.pl -downdb -webfrom annovar -build hg19 esp6500si_all humandb/
		#annotate_variation.pl -filter -dbtype esp6500si_ea -build hg19 -out ex1 example/ex1.avinput humandb/ -score_threshold 0.05
		#annotate_variation.pl -filter -dbtype esp6500si_ea -build hg19 -out ex1 example/ex1.avinput humandb/ -score_threshold 0.05 -reversees
		if File.exists?("#{HOMOSAPIENSDB}/#{HOMOSAPIENSBUILD}_esp6500siv2_all.txt")then
			puts "ESP available."
		else
			sh "perl #{SCRIPT} -buildver #{HOMOSAPIENSBUILD} -downdb -webfrom annovar esp6500siv2_all #{HOMOSAPIENSDB}" do |ok, res|
				if ! ok then
					puts "ESP setup failed (status = #{res.exitstatus})"
					abort
				end
			end
		end

		#GERP++ annotations
		puts "Downloading GERP++..."
		#annotate_variation.pl -downdb -buildver hg19 -webfrom annovar gerp++gt2 humandb/
		#annotate_variation.pl -filter -dbtype gerp++gt2 -out ex1 -build hg19 example/ex1.avinput humandb/
		if File.exists?("#{HOMOSAPIENSDB}/#{HOMOSAPIENSBUILD}_gerp++gt2.txt") then
			puts "gerp++gt2 available."
		else
			sh "perl #{SCRIPT} -buildver #{HOMOSAPIENSBUILD} -downdb -webfrom annovar  gerp++gt2 #{HOMOSAPIENSDB}" do |ok, res|
				if ! ok then
					puts "gerp++gt2 setup failed (status = #{res.exitstatus})"
					abort
				end
			end
		end

		#CG (complete genomics) frequency annotations
		puts "Downloading CG..."
		#annotate_variation.pl -downdb -webfrom annovar -build hg19 cg69 humandb/
		#annotate_variation.pl -filter -out ex1 -dbtype cg69 -build hg19 example/ex1.avinput humandb/
		#annotate_variation.pl -filter -dbtype cg69 -build hg19 example/ex1.avinput humandb/ -score_threshold 0.05 -out ex1
		if File.exists?("#{HOMOSAPIENSDB}/#{HOMOSAPIENSBUILD}_cg69.txt")then
			puts "cg69 available."
		else
			sh "perl #{SCRIPT} -downdb -webfrom annovar -build #{HOMOSAPIENSBUILD}  cg69 #{HOMOSAPIENSDB}" do |ok, res|
				if ! ok then
					puts "CG 69 setup failed (status = #{res.exitstatus})"
					abort
				end
			end
		end

		#CLINVAR database with Variant Clinical Significance (unknown, untested, non-pathogenic, probable-non-pathogenic, probable-pathogenic, pathogenic, drug-response, histocompatibility, other) and Variant disease name
		puts "Downloading CLINVAR database..."
		if File.exists?("#{HOMOSAPIENSDB}/#{HOMOSAPIENSBUILD}_clinvar_20140929.txt")then
			puts "clinvar_20140929 available."
		else
			sh "perl #{SCRIPT} -downdb -webfrom annovar -build #{HOMOSAPIENSBUILD} clinvar_20140929 #{HOMOSAPIENSDB}" do |ok, res|
				if ! ok then
					puts "clinvar_20140929 setup failed (status = #{res.exitstatus})"
					abort
				end
			end
		end
		#annotate_variation.pl -downdb -webfrom annovar -build hg19 exac03 humandb/
		puts "Downloading exac03 database..."
		if File.exists?("#{HOMOSAPIENSDB}/#{HOMOSAPIENSBUILD}_exac03.txt")then
			puts "exac03 available."
		else
			sh "perl #{SCRIPT} -downdb -webfrom annovar -build #{HOMOSAPIENSBUILD} exac03 #{HOMOSAPIENSDB}" do |ok, res|
				if ! ok then
					puts "exac03 setup failed (status = #{res.exitstatus})"
					abort
				end
			end
		end
		#annotate_variation.pl -filter -build hg19 -out ex4 -dbtype cosmic68 ex4.avinput humandb/
		puts "Downloading cosmic68 database..."
		if File.exists?("#{HOMOSAPIENSDB}/#{HOMOSAPIENSBUILD}_cosmic68.txt")then
			puts "cosmic68 available."
		else
			sh "perl #{SCRIPT} -downdb -webfrom annovar -build #{HOMOSAPIENSBUILD} cosmic68 #{HOMOSAPIENSDB}" do |ok, res|
				if ! ok then
					puts "cosmic68 setup failed (status = #{res.exitstatus})"
					abort
				end
			end
		end
		puts "********** end: manage_databases_filter_based **********"
	end
	desc "Extract ANNOVAR."
	task :extract_annovar => :download_annovar do
		puts "********** start: extract_annovar **********"
		cd ANNOVARLIB
		if  Dir.exists?("#{ANNOVARLIB}/annovar") then
			puts "annovar extracted"
		else
			path_annovar = "#{ANNOVARLIB}/annovar.latest.tar.gz"
			sh "tar -xzf #{path_annovar}"
		end
		puts "********** end: extract_annovar **********"
	end

	desc "Download ANNOVAR."
	task :download_annovar => :setup_annova_dir do
		if  File.exists?("#{ANNOVARLIB}/annovar.latest.tar.gz")
			puts "annovar.latest.tar.gz available."
		else
			puts "annovar.latest.tar.gz not available."
			puts "please get annovar  http://www.openbioinformatics.org/annovar "
			url_annovar = "http://www.openbioinformatics.org/annovar/"
			abort("Get ANNOVAR from #{url_annovar} and save at #{ANNOVARLIB}")
		end
		puts "********** end: download_annovar **********"
	end

	desc "setup_dir"
	task :setup_annova_dir => :environment do
		puts "********** start: setup_annova_dir **********"
		puts "Setting up annova..."
		puts "set #{ANNOVARBASE}"
		if  Dir.exists?(ANNOVARBASE)
			puts  "ANNOVARBASE available"
			cd ANNOVARBASE
		else
			puts"ANNOVARBASE not available. Creating it for you."
			mkdir_p ANNOVARBASE
			cd  ANNOVARBASE
		end
		puts "set #{ANNOVARLIB}"
		if  Dir.exists?(ANNOVARLIB)
			puts "ANNOVARLIB available"
			cd ANNOVARLIB
		else
			puts "ANNOVARLIB not available. Creating it for you."
			puts ANNOVARLIB
			mkdir_p ANNOVARLIB
		end
		puts "********** end: setup_annova_dir **********"
	end

	def find_multianno(tar)
		long_link = '././@LongLink'
		dest = nil
		ret = {
				content:  nil,
				fullname:  nil,
				organism: nil
		}
		tar.each do |entry|
			if entry.full_name == long_link
				dest = File.join dest.to_s, entry.read.strip
				next
			end
			dest ||= File.join dest.to_s, entry.full_name
			if dest =~ /.*_multianno.csv$/ then
				ret[:fullname] = dest
				ret[:content] = entry.read
				if (dest.index(".hg19_")) then
					ret[:organism] = Organism.find_by_name "homo sapiens"
				elsif (dest.index(".mm9_")) then
						ret[:organism] = Organism.find_by_name "mus musculus"
				end
			end
			dest = nil
		end
		ret
	end

	desc "Parse an Archive that was created as part of the Annotation Process and check the consistency for a list of fields."
	task :check_with_archives => :environment do
		puts "********** start: Checking with archive **********"
		annovar = AnnovarAnnotation.new()
		total = 0
		files = Dir["tmp/*annovar.tar.gz"]
		files.each_with_index do |archname, fidx|
			File.open(archname, "rb") do |file|
				Zlib::GzipReader.wrap(file) do |gz|
					Gem::Package::TarReader.new(gz) do |tar|
						puts "#################################"
						puts "STATUS: #{(fidx+1)}/#{files.size} files processed"
						puts "#################################"
						entry = find_multianno(tar)
						content = entry[:content]
						full_name = entry[:fullname]
						organism = entry[:organism]
						puts "no multianno for human found in #{archname}" if content.nil?
						next if content.nil?
						puts "unknow organism" if organism.nil?
						next if organism.nil?
						puts "Processing: #{full_name} (#{organism.name})"
						header = nil
						lines = content.split("\n")
						totallines = lines.size
						lines.each_with_index do |line, lineno|
							next if line =~ /^#/
							if header.nil?
								header = line.strip.split(",")
								next
							end
							rec = CSV.parse_line(line, headers: header, col_sep: ",").to_hash
							template = {
									"wgrna_name"                      => (annovar.multi_key_entry rec["wgRna"])["Name"],
									"micro_rna_target_score"          => (annovar.multi_key_entry rec["targetScanS"])["Score"],
									"micro_rna_target_name"           => (annovar.multi_key_entry rec["targetScanS"])["Name"],
									"tfbs_score"                      => (annovar.multi_key_entry rec["tfbsConsSites"])["Score"],
									"tfbs_motif_name"                 => (annovar.multi_key_entry rec["tfbsConsSites"])["Name"],
									#"genomic_super_dups_score"        => (annovar.multi_key_entry rec["genomicSuperDups"])["Score"],
									#"genomic_super_dups_name"         => (annovar.multi_key_entry rec["genomicSuperDups"])["Name"],
									"gwas_catalog"                    => (annovar.multi_key_entry rec["gwasCatalog"])["Name"],
									"cosmic68_id"                     => (annovar.multi_key_entry rec["cosmic68"])["ID"],
									"cosmic68_occurence"              => (annovar.multi_key_entry rec["cosmic68"])["OCCURENCE"],
									"variant_clinical_significance"   => (annovar.multi_key_entry rec["clinvar_20140929"])["CLINSIG"],
									"variant_disease_name"            => (annovar.multi_key_entry rec["clinvar_20140929"])["CLNDBN"],
									"variant_revstat"                 => (annovar.multi_key_entry rec["clinvar_20140929"])["CLNREVSTAT"],
									"variant_accession_versions"      => (annovar.multi_key_entry rec["clinvar_20140929"])["CLNACC"],
									"variant_disease_database_name"   => (annovar.multi_key_entry rec["clinvar_20140929"])["CLNDSDB"],
									"variant_disease_database_id"     => (annovar.multi_key_entry rec["clinvar_20140929"])["CLNDSDBID"]
							}
							if template.values.reject(&:nil?).size > 0 then

								if !template["variant_disease_name"].nil? then
									template["variant_disease_name"].gsub!("\\x2c", "")
								end

								total += 1
								%w(variant_clinical_significance variant_disease_name variant_revstat variant_accession_versions variant_disease_database_name variant_disease_database_id).each do |k|
									template[k] = template[k].to_s.split(",").uniq.join(",") unless template[k].nil?
									template[k] = nil if template[k] == "."
								end
								condition = {
										"variation_id"										=> rec["Otherinfo"],
										"organism_id"											=> organism.id
								}
								print("\t#{lineno}/#{totallines} ##{condition["variation_id"]}")
								num_affected = Annovar.where(condition).update_all(template)
								print(" => #{num_affected}                  \r") if num_affected > 0
								print("\r")
							end
						end

						print("\n #{full_name} DONE --> #{total} variants corrected\n")
					end
				end
			end
		end
		print("\n")
		puts "********** end: Checking with archive **********"
	end

end