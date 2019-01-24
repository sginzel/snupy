module SnupyAgain
	module Aqua
		module AquaStub
			class SnupyErbParser < OpenStruct
				def render(template)
					ERB.new(template).result(binding)
				end
			end
			
			def stub_template_dir()
				File.join(Rails.root, "lib", "aqua", "templates")
			end
			
			def check_outdir(outdir)
				if !Dir.exists?(outdir)
					FileUtils.mkdir_p(outdir)
				end
			end
			
			def generate_rake (tool_name, tool_model, outdir)
				check_outdir(outdir)
				fin = File.join(stub_template_dir, "annotations", "annotation.rake.erb")
				fout = File.join(outdir, "#{tool_name}.rake")
				puts "Generating Rakefile".blue
				parse_template(fin, fout, {tool_name: tool_name, tool_model: tool_model})
			end
			def generate_tool (tool_name, tool_model, outdir)
				check_outdir(outdir)
				fin = File.join(stub_template_dir, "annotations", "annotation_tool.rb.erb")
				fout = File.join(outdir, "#{tool_name}_annotation.rb")
				puts "Generating annotation class".blue
				parse_template(fin, fout, {tool_name: tool_name, tool_model: tool_model})
				generate_tool_config(tool_name, tool_model, outdir)
			end
			def generate_tool_config (tool_name, tool_model, outdir)
				check_outdir(outdir)
				fin = File.join(stub_template_dir, "annotations", "annotation_config.yaml.erb")
				fout = File.join(outdir, "#{tool_name}_config.yaml")
				puts "Generating annotation config".blue
				parse_template(fin, fout, {tool_name: tool_name, tool_model: tool_model})
			end
			def generate_model (tool_name, tool_model, outdir)
				check_outdir(outdir)
				fin = File.join(stub_template_dir, "annotations", "annotation.rb.erb")
				fout = File.join(outdir, "#{tool_name}.rb")
				puts "Generating model and migration".blue
				parse_template(fin, fout, {tool_name: tool_name, tool_model: tool_model})
				
				fin = File.join(stub_template_dir, "annotations", "annotation_migration.rb.erb")
				fout = File.join(outdir, "#{tool_name}_migration.rb")
				parse_template(fin, fout, {tool_name: tool_name, tool_model: tool_model})
			end
			def generate_query (tool_name, tool_model, outdir)
				check_outdir(outdir)
				fin = File.join(stub_template_dir, "queries", "query.rb.erb")
				fout = File.join(outdir, "query_#{tool_name}.rb")
				puts "Generating query".blue
				parse_template(fin, fout, {tool_name: tool_name, tool_model: tool_model})
			end
			def generate_filter (tool_name, tool_model, outdir)
				check_outdir(outdir)
				fin = File.join(stub_template_dir, "filters", "filter.rb.erb")
				fout = File.join(outdir, "filter_#{tool_name}.rb")
				puts "Generating Filter".blue
				parse_template(fin, fout, {tool_name: tool_name, tool_model: tool_model})
			end
			def generate_aggregation (tool_name, tool_model, outdir)
				check_outdir(outdir)
				fin = File.join(stub_template_dir, "aggregations", "aggregation.rb.erb")
				fout = File.join(outdir, "aggregation_#{tool_name}.rb")
				puts "Generating aggregation".blue
				parse_template(fin, fout, {tool_name: tool_name, tool_model: tool_model})
			end
			def parse_template(fin_path, fout_path, locals)
				if File.exists?(fout_path)
					puts "[ERROR] #{fout_path} already exists".red
					puts "[ERROR] doing nothing".red
					return nil
				end
				
				fin = File.new(fin_path, "r")
				parser = SnupyErbParser.new(locals)
				content = parser.render(fin.read)
				fin.close
				puts "#{fin_path}".cyan
				puts "\t=> #{fout_path}".cyan
				fout = File.new(fout_path, "w+")
				fout.write(content)
				fout.close
				fout_path
			end
		end
	end
end