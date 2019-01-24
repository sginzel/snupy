
namespace :package do
	desc "Package application to archive"
	task :app, [:file] => [:environment] do |t, args|
		args.with_defaults(:file => "#{Rails.root}/public/snupy.tar.gz")
 		tarfile = args[:file]
 		
 		puts "Find files to package..."
 		files = (`svn ls --recursive`.split("\n") + Dir["doc/**/**"]).uniq
 		files.reject!{|f| f == "config/database.yml"}
 		files.reject!{|f| f == "config/variant_effect_predictor.yaml"}
 		files.reject!{|f| f == "doc/TODO.txt"}
 		files.reject!{|f| f == "doc/rails_generate_controller_and_models.txt"}
 		files.reject!{|f| f == "lib/tasks/migrate.rake"}
 		
 		# create archive
 		puts "Creating tar archive with #{files.size} files to #{tarfile}..."
 		system("tar --no-recursion -czf #{tarfile} #{files.map{|f| "'#{f}'" }.join(" ")}")
	end
	
	desc "Package current sample tags"
	task :sampletags, [:file] => :environment do |t, args|
		args.with_defaults(:file => "#{Rails.root}/db/sample_tag_seeds.json")
 		jsonfile = args[:file]
 		
 		puts "Storing Sample in #{jsonfile}"
 		File.open(jsonfile, "w+"){|fout| 
 			arr2write = SampleTag.all.map(&:attributes)
 			fout.write(arr2write.to_json)
 		}
	end
		
end