namespace :stringdb do

	desc "Setup: Download StringDB data and import them to SNuPy"
	task :setup => :environment do
		Stringdb.import(9606, Organism.find_by_name("homo sapiens").id)
		Stringdb.import(10090, Organism.find_by_name("mus musculus").id)
		print "OK. DONE.\n"
	end
	
	
	desc "Unsetup: Does nothing for StringDB"
	task :remove => :environment do
		print "OK. DONE.\n"
	end

	desc "Clean: Removes stringdb data from the cache directory."
	task :clean => :environment do
		
	end

	desc "Clear: Removes all interactions and protein alias information from the database"
	task :clear => :environment do
		Stringdb.delete_all
		StringProteinLink.delete_all
		StringProteinAction.delete_all
		StringProteinAlias.delete_all
		print "OK. DONE.\n"
	end
	
end