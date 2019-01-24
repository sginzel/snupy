if Rails.env == "development"
	if !defined?(::Rake) and !ARGV.include?("db:migrate") then # dont execute during migration
		Dir["#{Rails.root}/app/models/**/"].each do |dirname|
			#d " --> loading files from #{dirname}"
			Dir.new(dirname).to_a.each do |filename|
				next unless filename =~ /.rb$/
				model_name = File.basename(filename)
				#d " ----> loading #{dirname + "/" + filename}"
				require_dependency dirname + "/" + filename 
				# load dirname + "/" + filename 
			end
		end
	end
end
