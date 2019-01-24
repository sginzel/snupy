namespace :digenic do
	
	desc "Setup: Import all files in the ./data folder"
	task :setup => :environment do
		Digenic.import(Digenic.configuration)
		print "OK. DONE.\n"
	end
	
	desc "Import: Adds specific digenic associations to the database"
	task :import, [:name] => :environment do |t, args|
		Digenic.import(Digenic.configuration, args[:name])
	end
	
	desc "Unsetup: does nothing."
	task :remove => :environment do
		print "Nothing to do..\n"
	end
	
	desc "Clean: Does nothing."
	task :clean => :environment do
		print "Nothing to do..\n"
	end
	
	desc "Clear: Removes all digenic interactions"
	task :clear => :environment do
		Digenic.delete_all
		print "OK. DONE.\n"
	end

end