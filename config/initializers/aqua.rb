load("lib/aqua/aqua_color.rb")
load("lib/aqua/aqua_helper.rb")
load("lib/aqua/aqua_status.rb")
load("lib/aqua/aqua.rb")
# dont execute during migration
if !(defined?(::Rake) && (ARGV.include?("db:migrate") || ARGV.any?{|arg| arg =~ /.*aqua:migrate.*/})) then
	# load Aqua manually and not through the autoload mechanism
	# load("lib/aqua/aqua_controller.rb")
	@@AQUALOCK = Mutex.new
	Aqua._init()
else
	if defined?(::Rake) && ARGV.any?{|arg| arg =~ /.*aqua:migrate.*/} then
		# This causes the rake file to be loaded twice. Thus it will execute every task twice
		# aqua.rake is already loaded when loading the base Rakefile - I will leave this here in cause you want to use it without the Rakefile
		# load("lib/aqua/aqua.rake")
	else
		@@AQUALOCK = Mutex.new
		#Aqua._init()
	end
end
