namespace :omim do
	
	desc "Setup omim."
	task :setup => [:environment, :download_omim, :check_tools] do |t, args|
		# Do everything neccessary to setup your tool
		# You can also define tasks and add them to the dependency chain
		genemapfile = File.join(OmimAnnotation.datadir, "genemap2.txt")
		OmimGenemap.import_genemap2(genemapfile)
	end

	desc "Remove: Removes all traces of omim"
	task :remove => :environment do
		print "OK. DONE.\n"
	end

	desc "Clear: Removes all annotations done with omim"
	task :clear => :environment do
		Omim.delete_all
		print "OK. DONE.\n"
	end
	
	desc "Clean omim - remove installation"
	task :clean => :environment do
		puts "Clear installation"
	end

	desc "Checks a list of tools"
	task :check_tools do
		%w(bash).each do |cmd|
			check(cmd)
		end
	end

	desc "Download OMIM"
	task :download_omim do
		if !OmimAnnotation.config("urls").nil? && File.exists?(OmimAnnotation.config("urls")) then
			urls = YAML.load(File.open(OmimAnnotation.config("urls"), "r").read)
		else
			puts "urls entry in omim.yaml not found.".blue
			puts "Please provide a link to the genemap2.txt file that you received as part of your license.".blue
			answer = STDIN.gets.strip
			if (answer.to_s == "")
				puts "No URL given.".yellow
				exit 1
			else
				urls = {"genemap2" => answer}

			end
		end
		urls.each do |name, file|
			localfile = File.join(OmimAnnotation.datadir, File.basename(file))
			download(file, localfile)
		end
	end

	def check(cmd)
		print "Checking #{cmd}..."
		tbxpath = OmimAnnotation.get_executable(cmd)
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
		if !(File.exists?fname) then
			bytes = IO.copy_stream(open(url), fname)
			print sprintf("DONE %d bytes\n".green, bytes)
		else
			print sprintf("EXISTS\n".green)
		end
		fname
	end
	
end