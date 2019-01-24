# Watch out - this rake task might be loaded twice...
## http://www.softwaremaniacs.net/2015/01/a-rake-task-named-databaserake-task-is.html
namespace :aqua do
	require 'aqua/aqua_stub'
	include SnupyAgain::Aqua::AquaStub
	puts "LOADING AQUA RAKE TASK FILE..." if Rails.env == "development" # this is useful because tasks might be executed twice if the file is loaded twice...
	
	desc "Generates a stub for a new tool. USAGE: aqua:generate[toolname,annotation.rake:annotation.tool:annotation.model:query:filter:aggregation]"
	task :generate, [:tool, :types] => :environment do |t, args|
		outdir = File.join(Rails.root, "extras", "snupy_again", "aqua")
		tool = args[:tool]
		types = (args[:types] || "annotation.rake:annotation.tool:annotation.model:query:filter:aggregation").split(":")
		tool_model = tool.singularize.camelize
		tool_name = tool_model.underscore
		
		outdirs = {
			"annotation.rake"  => File.join(outdir, "annotations", tool_name),
			"annotation.tool"  => File.join(outdir, "annotations", tool_name),
			"annotation.model" => File.join(outdir, "annotations", tool_name),
			"query"            => File.join(outdir, "queries"),
			"filter"           => File.join(outdir, "filters", tool_name),
			"aggregation"      => File.join(outdir, "aggregations", tool_name)
		}
		types.each do |type|
			case type
			when "annotation"
				generate_rake tool_name, tool_model, outdirs["annotation.rake"]
				generate_tool tool_name, tool_model, outdirs["annotation.tool"]
				generate_model tool_name, tool_model, outdirs["annotation.model"]
			when "annotation.rake"
				generate_rake tool_name, tool_model, outdirs["annotation.rake"]
			when "annotation.tool"
				generate_tool tool_name, tool_model, outdirs["annotation.tool"]
				generate_model tool_name, tool_model, outdirs["annotation.model"]
			when "annotation.model"
				generate_model tool_name, tool_model, outdirs["annotation.model"]
			when "query"
				generate_query tool_name, tool_model, outdirs["query"]
			when "filter"
				generate_filter tool_name, tool_model, outdirs["filter"]
			when "aggregation"
				generate_aggregation tool_name, tool_model, outdirs["aggregation"]
			else
				raise "Not supported #{type}"
			end
		end
	end
	
	desc "Lists available types for generating stubs."
	task :generate_list_types => :environment do |t, args|
		
		descs = {
			"annotation"       => "Creates a new annotation",
			"annotation.rake"  => "Creates a rake file with setup tasks",
			"annotation.tool"  => "Creates a Annotation-model that contains methods to start and store the annotation. ",
			"annotation.model" => "Creates a ActiveRecord model of annotation data to store",
			"query"            => "Createa a query folder in the AQUA directory with a stub query.",
			"filter"           => "Createa a filter folder in the AQUA directory with a stub filter.",
			"aggregation"      => "Createa a aggregation folder in the AQUA directory with a stub aggregation."
		}
		descs.each do |k, v|
			puts "#{k}:\t#{v}"
		end
	end
	
	desc "Execute a task defined by a tool"
	task :task, [:tool, :task] => :environment do |t, args|
		tool = args[:tool]
		redirect_task(tool, args[:task], extras = args.extras)
	end
	
	desc "Start the setup process of an annotation tool. This should download and setup all files needed to run the tool."
	task :setup, [:tool] => :environment do |t, args|
		tool = args[:tool]
		redirect_task(tool, "setup")
	end
	
	desc "Execute a task defined by a tool"
	task :task, [:tool, :task] => :environment do |t, args|
		tool = args[:tool]
		redirect_task(tool, args[:task])
	end
	
	
	desc "Show status of all recognized AquA modules. Parameters can be annotation, query, filter and aggregation."
	task :status, [:type] => :environment do |t, args|
		types = args[:type]
		
		types = "annotation,query,filter,aggregation" if types.nil?
		types = types.split(",").map(&:strip)
		
		types.each do |type|
			
			if type == "annotation" or type == "query" or type == "filter" or type == "aggregation" or
				 type == "annotations" or type == "queries" or type == "filters" or type == "aggregations" then
				summary = aqua_module_summary(type)
			else
				abort("Argument #{type} not recognized.")
			end
			# print summary
			summary.each do |rec|
				rec_header = rec["Klass"].to_s + "/" + (rec["Name"] || rec["Query"]).to_s
				puts "*" * (rec_header.size + 8)
				puts "*** " + rec_header + " ***"
				puts "*" * (rec_header.size + 8)
				rec.each do |colname, value|
					value = value.join(", ") if value.is_a?(Array)
					printf "\t%-20s %s\n", colname.to_s + ":", value.to_s
				end
				puts "-" * (rec_header.size + 8)
			end # of summary
		end # of types
	end
	
	desc "Start the removal process of an annotation tool. Executes clean and rollback of the tool."
	task :remove, [:tool] => [:clean, :rollback] do |t, args|
		tool = args[:tool]
		redirect_task(tool, "remove")
	end
	
	desc "clear all annotations that belong to a tool"
	task :clear, [:tool] => :environment do |t, args|
		puts "********** start: clear aqua annotations **********"
		
		tool_name = args[:tool]
		tool = Annotation.find_tool(tool_name.to_sym)
		organisms = tool.organism
		
		input = nil
		puts "All annotation data for #{tool.tool_name} from #{ActiveRecord::Base.connection.current_database}.#{tool.model.table_name} will be removed."
		puts "Are you sure? [Y/N]"
		while (!(%w(Y N).include?(input = STDIN.gets.strip)))
			puts "Only Y and N are allowed."
		end
		abort("Abort clearing of #{tool.tool_name} ") if input != 'Y'
		
		# Let the tool reset the data it created.
		redirect_task(tool_name, "clear")
		
		print "Resetting all VcfFiles...\n"
		## also reset all VcfFiles status
		# VcfFile.where(organism_id: organisms).where(status: "DONE").all(select: [:name, :id, :status, :type]).each do |vcf|
		VcfFile.nodata.includes(:aqua_status_annotations).each do |vcf|
			vcf.aqua_annotation_status(tool).revoke_annotation
		end
		puts "********** end: clear Aqua annotations **********\n"
	end
	
	# TODO: We have to check if the tool was deactivated before.
	desc "Clean: Removes the program and data used for the annotation."
	task :clean, [:tool] => :environment do |t, args|
		tool = args[:tool]
		begin
			puts "All binaries, libraries and caches for #{tool.camelcase} will be removed. The model table in the database will be removed."
			puts "Are you sure? [Y/N]"
			input = STDIN.gets.strip
		end until %w(Y N).include?(input)
		if input != 'Y'
			abort("Abort removal of #{tool.camelcase}")
		end
		
		# delete all files and libraries required by the tool. This can only be done by the tool itself.
		redirect_task(tool, "clean")
	end
	
	# TODO: choose migrate(:down) or change_table_name
	desc "Executes migration process of given tool. This should create one or more tables in the database where the annotation results are stored."
	task :migrate, [:tool] => :environment do |t, args|
		tool = args[:tool]
		puts "********** start: migrate #{tool.to_sym} tool **********"
		tool_migration_file = File.join(".", "extras", "snupy_again", "aqua", "annotations", tool, "#{tool}_migration.rb")
		if !File.exists?(tool_migration_file) then
			abort("#{tool_migration_file} does not exist for #{tool}")
		else
			load tool_migration_file
		end
		tool_migration_klass = eval("#{tool.to_s}_migration".camelcase)
		
		tool_migration_klass.migrate(:up)
		
		puts "********** end: migrate #{tool.to_s} tool**********"
		# ActiveRecord::Migrator.migrate MIGRATIONS_DIR, ENV['VERSION'] ? ENV['VERSION'].to_i : nil
	end
	
	# TODO: choose migrate(:down) or change_table_name
	desc "Executes rollback process of given tool. This will destroy the table and all the annotated data in the database."
	task :rollback, [:tool] => :environment do |t, args|
		tool = args[:tool]
		tool_class = Annotation.find_tool(tool.to_sym)
		puts "********** start: rollback #{tool.to_sym} tool **********"
		tool_migration_file = File.join(".", "extras", "snupy_again", "aqua", "annotations", tool, "#{tool}_migration.rb")
		if !File.exists?(tool_migration_file) then
			abort("#{tool_migration_file} does not exist for #{tool}")
		else
			load tool_migration_file
		end
		tool_migration_klass = eval("#{tool.to_s}_migration".camelcase)
		
		tool_migration_klass.migrate(:down)
		
		print "Resetting all VcfFiles...\n"
		## also reset all VcfFiles status
		VcfFile.nodata.includes(:aqua_status_annotations).each do |vcf|
			vcf.aqua_annotation_status(tool_class).revoke_annotation
		end
		
		puts "********** end: rollback #{tool.to_sym} tool**********"
		# ActiveRecord::Migrator.migrate MIGRATIONS_DIR, ENV['VERSION'] ? ENV['VERSION'].to_i : nil
	end
	
	desc "Activate a tool. Performs the annotation for all VcfFiles."
	task :activate, [:tool] => :environment do |t, args|
		tool = args[:tool]
		puts "********** start: activate #{tool.to_sym} tool**********"
		tool_klass = Annotation.find_tool(tool.to_sym)
		abort "Tool (#{tool}) not found" if tool_klass.nil?
		tool_tbl = tool_klass.model.table_name
		
		puts "ACTIVATE: Finding ids to annotate..."
		idfile = File.join("tmp", "#{tool}_vcfs.ids")
		if !File.exists?(idfile)
			puts "#{idfile} dont exist: first annotation activation"
			vcfids = VcfFile.where(status: [:DONE, :ENQUEUED, :ANNOTATIONPROCESS, :INCOMPLETE]).where(organism_id: tool_klass.configuration[:organism]).pluck(:id)
		else
			puts "#{idfile} exist:"
			begin
				puts "Do you want to resume a previous annotation activation? (from #{idfile}) [Y/N]"
				input = STDIN.gets.strip.downcase
			end until %w(y n).include?(input)
			if input == 'y'
				puts "ACTIVATE: using previous id list..."
				vcfids = YAML.load_file(idfile)
			else
				puts "ACTIVATE: using all VCFFile ids..."
				vcfids = VcfFile.where(status: [:DONE, :ENQUEUED, :ANNOTATIONPROCESS, :INCOMPLETE]).where(organism_id: tool_klass.configuration[:organism]).pluck(:id)
			end
		end
		
		File.open(idfile, 'w+') {|f| f.write vcfids.to_yaml }
		vcfids.each do |vcfid|
			vcf = VcfFile.select([:id, :status]).find(vcfid)
			puts "ACTIVATE: starting AquaAnnotationProcess ..."
			ap = AquaAnnotationProcess.new(vcfid)
			success = ap.start([tool_klass])
			if !success then
				abort "VCFfile (id: #{vcfid}) could not be annotated successfully."
			else
				## remove vcfids from file
				new_vcfids = YAML.load_file(idfile)
				new_vcfids.reject!{|id| id.to_s == vcfid.to_s}
				File.open(idfile, 'w+') {|f| f.write new_vcfids.to_yaml }
			end
		end
		puts "********** end: activate #{tool.to_sym} tool  **********"
	end
	
	desc "Start an annoation process for a VCFFile ID with a tool Usage: [toolname,vcfid]."
	task :annotatevcf, [:tool,:vcfid] => :environment do |t, args|
		tool = args[:tool]
		vcfids = args[:vcfid].split(",")
		puts "********** start: annotate #{tool.to_sym} tool**********"
		tool_klass = Annotation.find_tool(tool.to_sym)
		abort "Tool (#{tool}) not found" if tool_klass.nil?
		
		puts "Annotate #{vcfids.size} VcfFiles"
		vcfids.each do |vcfid|
			vcf = VcfFile.select([:id, :status]).find(vcfid)
			vcf.status = "CREATED"
			vcf.save!
			puts "Annotate: starting AquaAnnotationProcess ... #{vcfid}"
			ap = AquaAnnotationProcess.new(vcfid)
			success = ap.start([tool_klass])
			if !success then
				abort "VCFfile (id: #{vcfid}) could not be annotated successfully."
			end
		end
		puts "********** end: annotate #{tool.to_sym} tool  **********"
	end
	
	desc "Annotate a VCF File [toolname,organism,path_to_vcf]."
	task :annotate, [:tool,:organism,:vcfpath] => :environment do |t, args|
		if args.size == 0 || ![:tool,:organism,:vcfpath].all?{|x| !args[x].nil?} then
			puts "Please use bundle exec rake aqua:annotate[toolname,organism,path_to_vcf] to annotate a vcf file."
		end
		tool = args[:tool]
		organism = Organism.find_by_name(args[:organism])
		abort "Organism (#{args[:organism]}) not found. [#{Organism.pluck(:name).sort.join(",")}]" if organism.nil?
		paths = args[:vcfpath].split(",")
		puts "********** start: annotate #{tool.to_sym} tool**********"
		tool_klass = Annotation.find_tool(tool.to_sym)
		abort "Tool (#{tool}) not found" if tool_klass.nil?
		
		puts "** Annotate #{paths.size} VcfFiles **"
		paths.each do |path|
			if (!File.exists?(path))
				puts "--> #{path} not found. Skip processing."
			end
			tinst = tool_klass.new({})
			tmpvcf = VcfFile.new()
			tmpvcf.organism = organism
			tmpvcf.id = -1
			converted_input = nil
			# converted_input = AquaAnnotationProcess.vcf_to_vcf(path, tmpvcf) if tool_klass.configuration[:input] == :vcf
			converted_input = path if tool_klass.configuration[:input] == :vcf # if we do it like this the input VCF is not reduced to its variants and all other information are preseverd.
			converted_input = AquaAnnotationProcess.vcf_to_csv(path, tmpvcf) if tool_klass.configuration[:input] == :csv
			abort "Input format not recognized" if converted_input.nil?
			fout = tinst.perform_annotation(converted_input, tmpvcf)
			puts "SUCESS_ANNOTATION	#{path}	->	#{converted_input}	->	#{fout}"
		end
		puts "********** end: annotate #{tool.to_sym} tool  **********"
	end
	
	desc "Generates the documentation for the given tool"
	task :doc, [:tool] => :environment do |t, args|
		tool = args[:tool]
		files = Dir["extras/snupy_again/aqua/annotations/#{tool}/**"]
		files += Dir["extras/snupy_again/aqua/queries/**"]
		files += Dir["extras/snupy_again/aqua/filters/#{tool}/**"]
		files += Dir["extras/snupy_again/aqua/aggregations/#{tool}/**"]
		puts `rdoc -m #{tool} -t #{tool} -o doc/aqua/#{tool} #{files.join(" ")}`
	end
	
	desc "Update quantiles [toolname]."
	task :update_quantiles, [:tool, :obs] => :environment do |t, args|
		tool = args[:tool]
		stop_after = (args[:obs] || 100000).to_i
		tool_klass = Annotation.find_tool(tool.to_sym)
		puts "Updating quantiles for #{tool_klass.configuration(:name)} with #{stop_after} observations".green
		(tool_klass.configuration[:organism] || []).each do |organism|
			tool_klass.update_quantile_estimates(organism.id, stop_after)
		end
		puts "Done updating quantiles #{tool_klass.configuration(:name)}".green
	end
	
	def redirect_task(tool, task, extras = nil)
		tool_rakefile = File.join(".", "extras", "snupy_again", "aqua", "annotations", tool, "#{tool}.rake")
		if (!File.exists?(tool_rakefile)) then
			puts "Rake file not found for tool #{tool} (#{tool_rakefile})"
			return false
		end
		puts "loading RAKE #{tool_rakefile}"
		load tool_rakefile
		taskname = "#{tool}:#{task}"
		if Rake::Task.tasks.map(&:name).include?(taskname) then
			if extras.nil?
				Rake::Task[taskname].invoke
			else
				Rake::Task[taskname].invoke(extras)
			end
		else
			puts "Task #{taskname} not found. Ignoring."
			return false
		end
	end
	
	def change_table_name(oldname, newname)
		puts "Renaming table #{oldname} to #{newname}"
		ActiveRecord::Migration.rename_table(oldname, newname)
	end
	
	def delete_model(model)
		print "Deleting #{model}..."
		model.delete_all
		print "Deleting done\n"
	end
	
	def aqua_module_summary(type)
		ret_annotations = Aqua.annotations
		ret_queries = Aqua.queries
		ret_aggregations = Aqua.aggregations
		ret_filters = []
		
		ret_annotations = ret_annotations.map{|klass, config|
			{
				"Klass" => klass.name, 
				"Toolname" => config[:tool],
				"Name" => config[:name],
				"Label" => config[:label], 
				"Input Format" => config[:input],
				"Output Format" => config[:output], 
				"Supported Organisms" => config[:organism].map(&:name).join(", "),
				"Required Models" => config[:model].map{|m|
					if m.is_a?(Array) # config[:model] can be an Array or a Hash - but when it is a Hash, then m will be [mode, [relations]]
						if m[1].is_a?(Array) then
							"#{m[0]} => #{m[1].map(&:name).join(" & ")}"
						else
							m.map{|ma| ma.name}.join(" & ")
						end
					else
						m.name
					end
				}.join("<br>").html_safe,
				"Satisfied?" => klass.satisfied?,
				"Ready?" => klass.ready?,
				"Type" => klass.type
			}
		}
		
		ret_queries = ret_queries.map{|type, klass2query|
			klass2query.map do |qklass, queries|
				queries.map do |qname, config|
					filters = qklass.filters[qname]
					filters = [] if filters.nil?
					filters.each do |f|
						collector_output = "METHOD NOT FOUND"
						if f.respond_to?(f.collection_method) then
							begin
								if f.public_methods(false).include?(f.collection_method.to_sym) then
									collector_output = f.send(f.collection_method, {}).first(64).map{|rec| 
										rec.pretty_inspect.split("\n")
									}
									collector_output = "EMPTY" if collector_output == ""
								else
									collector_output = "NA" # not implemented for this filter.
								end
							rescue
								collector_output = "Could not determine automatically."
							end
						end
						ret_filters << {
							"Klass" => f.class.name, 
							"Name" => f.name,
							"Label" => f.label,
							"Method" => f.filter_method,
							"Checked?" => f.checked,
							"Organisms" => f.organism.map(&:name).join(", "),
							"Applicable?" => f.applicable?, # f.organism.map{|o| "#{o.name}(#{f.applicable?(o.id)})"}.join(", "),
							"Requirements" => f.requirements,
							"Query" => "#{qklass.name}:#{qname}",
							"Collector" => f.collection_method.to_s,
							"Collector Output" => collector_output
						}
					end
					{
						"Klass" => qklass.name, 
						"Query" => qname,
						"Type"  => type,
						"Label" => config[:label],
						"Default" => config[:default],
						"Combine default" => config[:combine],
						"Tooltip" => config[:tooltip],
						"Supported Organisms" => config[:organism].map(&:name).join(", "),
						"Priority" => config[:priority],
						"Filter" => filters.map{|f|
							f.class.name + "(#{f.name.to_s})[#{f.applicable?}]"
						}
					}
				end
			end
		}.flatten
		
		ret_aggregations = ret_aggregations.map{|aklass, aggregations|
			aggregations.map do |aname, config|
				{
					"Klass" => aklass.name,
					"Name" => aname 
				}.merge(config)
			end
		}.flatten
		
		return ret_annotations if type == "annotation"
		return ret_queries if type == "query"
		return ret_filters if type == "filter"
		return ret_aggregations if type == "aggregation"
		return ret_annotations if type == "annotations"
		return ret_queries if type == "queries"
		return ret_filters if type == "filters"
		return ret_aggregations if type == "aggregations"
		raise "Type not supported."
	end
end