require 'io/console'
namespace :snupy do
	
	desc "Lists the required shell variables to use database_setup"
	task :database_setup_template do
		puts ((
		<<EOS
export SNUPYHOST="localhost"
export SNUPYPORT=3306
export SNUPYUSER="snupy"
export SNUPYPASSWORD="$(pwgen -s 64 1)"
export SOCKET="/var/run/mysqld/mysqld.sock"
export SNUPY_APIUSER="snupy"
export SNUPY_APIPASSWORD="$(pwgen -s 64 1)"

## SETUP database with the appropriate random password
sudo mysql -h $SNUPYHOST -uroot -P $ SNUPYPORT -e "GRANT ALL PRIVILEGES ON *.* TO '$SNUPYUSER'@'%' IDENTIFIED BY '$SNUPYPASSWORD';"
### add read-only user to be used for API connections, so people can't do bad things using SQL statements
sudo mysql -h $SNUPYHOST -uroot -P $ SNUPYPORT -e "GRANT SELECT ON *.* TO '$SNUPY_APIUSER'@'%' IDENTIFIED BY '$SNUPY_APIPASSWORD';"
EOS
		).yellow)
	end
	
	desc "Parses the database.yml.erb template to STDOUT"
	task :database_setup do
		@ask_cache = {}
		STDOUT.write parse("config/database.yml.erb")
	end
	
	desc "Count all instances of all models"
	task :size => :environment do
		ActiveRecord::Base.descendants.each do |modelname|
			printf("%-32s", modelname.name)
			printf("%-8s", model.count())
			print "#{model.unscoped.count()} (unscoped)"
			print "\n"
		end
	end
	
	desc "Count all rows in all tables"
	task :count => :environment do
		tbls = ActiveRecord::Base.connection.execute("SHOW TABLES").to_a.flatten.sort
		tbls.reject! {|tbl| tbl == "schema_migrations"}
		tbls.each do |tbl|
			tblsize = ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM #{tbl}").to_a.flatten.first
			printf("%-#{tbls.map(&:length).max + 1}s", tbl)
			print "#{tblsize}\n"
		end
	end

	def parse(file)
		template = File.open(file, "r", &:read)
		ret = ERB.new(template.to_s).result(binding)
		return ret
	end
	
	def ask(text="", default = nil, echo=true)
		if text.to_s.size > 0
			STDERR.printf("%s(default: %s):\n", text.to_s, default.to_s)
		end
		if @ask_cache[text].nil?
			reply = ((echo)?(STDIN.gets):(STDIN.noecho(&:gets))).strip
			if reply.to_s == ""
				@ask_cache[text] = default.to_s
			else
				@ask_cache[text] = reply.to_s
			end
		end
		@ask_cache[text]
	end
end