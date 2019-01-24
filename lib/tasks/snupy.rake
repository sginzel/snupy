namespace :snupy  do
	
	all_models = [:Variation, :Region, :Alteration, :VcfFile, :Sample, :Experiment,
								:VariationCall, :VariationAnnotation, :GeneticElement, :Consequence, :LossOfFunction,
								:LongJob, :VariationTag, :VariationCallTag, :SampleTag]
	
	desc "clear all annotations"
	task :clear_annotation => :environment do 
		[
			:VariationAnnotation, :GeneticElement, :Consequence, :LossOfFunction
		].each do |modelname|
			model = Kernel.const_get(modelname)
			raise "Not a model (#{modelname})" unless model.ancestors.include?(ActiveRecord::Base)
			print "Deleting #{modelname}..."
			model.delete_all
			print "done\n"
		end
		print "Deleting variation_annotation_has_consequence..."
		ActiveRecord::Base.connection.execute("DELETE FROM variation_annotation_has_consequence")
		print "Resetting all VcfFiles..."
		## also reset all VcfFiles status
		VcfFile.all(select: [:name, :id, :status, :type]).each do |vcf|
			vcf.status = "CREATED"
			vcf.save
		end
	end
	
	desc "clear all data that was created by users-this is nothing to mess around with!"
	task :clear_variation_data => :environment do 
		[
			:VariationAnnotation, :GeneticElement, :Consequence, :LossOfFunction,
			:VariationCall, :VariationCallTag, :VariationTag, :SampleTag,
			:Variation, :Alteration, :Region
		].each do |modelname|
			model = Kernel.const_get(modelname)
			raise "Not a model (#{modelname})" unless model.ancestors.include?(ActiveRecord::Base)
			print "Deleting #{modelname}..."
			model.delete_all
			print "done\n"
		end
		%w(variation_call_has_variation_call_tag variation_has_variation_tag variation_annotation_has_consequence sample_has_sample_tag).each do |tbl|
			print "Deleting #{tbl}..."
  		ActiveRecord::Base.connection.execute("DELETE FROM #{tbl}")
  		print "done\n"
		end
		## also reset all VcfFiles status
		print "Resetting all VcfFiles..."
		VcfFile.all(select: [:name, :id, :status, :type]).each do |vcf|
			vcf.status = "CREATED"
			vcf.save
		end
	end
	
  desc "clear the database"
  task :clear => :environment do
		all_models.each do |modelname|
			model = Kernel.const_get(modelname)
			raise "Not a model (#{modelname})" unless model.ancestors.include?(ActiveRecord::Base)
			print "Destroying #{modelname}..."
			model.unscoped.destroy_all
			print "done\n"
		end
	end
	
	desc "Delete rows in a tables, but not the migration table"
  task :delete, [:table, :condition] => :environment do |t, args|  
  	args.with_defaults(:table => nil, :condition => nil) 
  	tbl = args[:table]
  	condition = args[:condition]
  	tbls = ActiveRecord::Base.connection.execute("SHOW TABLES").to_a.flatten.sort
  	tbls.reject!{|t| t == "schema_migrations"}
  	if tbls.include?(tbl) then
  		print "deleting #{tbl}..."
  		if condition.nil? then
  			ActiveRecord::Base.connection.execute("DELETE FROM #{tbl}")
  		else
  			ActiveRecord::Base.connection.execute("DELETE FROM #{tbl} WHERE #{condition}")
  		end
  		print "done\n"
  	else
  		puts "#{tbl} is not a table"
  	end
	end
	
	desc "Count all instances of all models"
  task :size => :environment do
		all_models.each do |modelname|
			model = Kernel.const_get(modelname)
			raise "Not a model (#{modelname}) (#{model.class})" unless model.ancestors.include?(ActiveRecord::Base)
			printf("%-32s", modelname)
			printf("%-8s", model.count())
			print "#{model.unscoped.count()} (unscoped)"
			print "\n"
		end
	end
	
	desc "Count all rows in all tables"
  task :count => :environment do
  	tbls = ActiveRecord::Base.connection.execute("SHOW TABLES").to_a.flatten.sort
  	tbls.reject!{|tbl| tbl == "schema_migrations"}
		tbls.each do |tbl|
			tblsize = ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM #{tbl}").to_a.flatten.first
			printf("%-#{tbls.map(&:length).max + 1}s", tbl)
			print "#{tblsize}\n"
		end
	end
	
end