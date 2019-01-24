module SnupyAgain
	module Profiler
		def self.profile(fname)
			return nil if Rails.env != "development"
			begin
				RubyProf.start
				yield
				results = RubyProf.stop
				
				outdir = File.join(Rails.root, "tmp", "profile")
				if !(Dir.exists?(outdir))
					Dir.mkdir(outdir)
				end
				
				# Print a flat profile to text
				File.open File.join(outdir, "#{fname}-graph.html"), 'w' do |file|
					RubyProf::GraphHtmlPrinter.new(results).print(file)
				end
				
				File.open File.join(outdir, "#{fname}-flat.txt"), 'w' do |file|
				# RubyProf::FlatPrinter.new(results).print(file)
					RubyProf::FlatPrinterWithLineNumbers.new(results).print(file)
				end
				
				File.open File.join(outdir, "#{fname}-stack.html"), 'w' do |file|
					RubyProf::CallStackPrinter.new(results).print(file)
				end
			ensure
				RubyProf.stop if RubyProf.running?
			end
			results
		end
		
	end
	
end