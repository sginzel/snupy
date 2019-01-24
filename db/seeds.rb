# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
if User.count == 0 then
	puts "No User found. Please enter a default user name: ".cyan
	name = (ENV["SNUPY_DEFAULT_USER_NAME"] || STDIN.gets.strip)
	puts "Full name: ".cyan
	fullname = (ENV["SNUPY_DEFAULT_USER_FULLNAME"] || STDIN.gets.strip)
	puts "E-Mail: ".cyan
	email = (ENV["SNUPY_DEFAULT_USER_EMAIL"] || STDIN.gets.strip)
	if name == ""
		puts "using default user: snupy".yellow
		name = "snupy"
		fullname = "SNuPy Default User"
		email = "none@snupy.com"
	end
	usr = User.create(name: name, full_name: fullname, is_admin: true, email: email)
	puts "Created #{usr}".green
end
if Rails.env == "development" then
  if User.find_by_name("developer").nil? then
    puts "Adding Developer"
    usr = User.new(name: "developer", full_name: "Senor Developer", is_admin: true, email: "none@example.com")
    usr.save!
  end
end

Organism.create(name: "homo sapiens") if Organism.find_by_name("homo sapiens").nil?
Organism.create(name: "mus musculus") if Organism.find_by_name("mus musculus").nil?

Institution.create(name: "BRS", contact: "Prof. Dr. Thiele", email: "ralf.thiele@h-brs.de", phone: "+49 (0)2241/865-281") if Institution.find_by_name("BRS").nil?
Institution.create(name: "UKD", contact: "Prof. Dr. med. Borkhardt", email: "Monika.Brockmann-Metz@med.uni-duesseldorf.de", phone: "+49 (0)211/81-17680") if Institution.find_by_name("UKD").nil?

# setup sample annotation
if SampleTag.count == 0 then
	stags = YAML.load(File.open(Rails.root.to_s + "/db/sample_tags_status.yaml", "r").read)
	dtags = YAML.load(File.open(Rails.root.to_s + "/db/sample_tags_disease.yaml", "r").read)
	ttags = YAML.load(File.open(Rails.root.to_s + "/db/sample_tags_tissue.yaml", "r").read)
	othrtags = YAML.load(File.open(Rails.root.to_s + "/db/sample_tags_other.yaml", "r").read)
	begin
		[dtags, ttags, stags, othrtags].each do |tags|
			tags.each do |tag|
				newtag = SampleTag.create(tag)
				newtag.save!
			end
		end
	rescue 
		SampleTag.delete_all
		raise 
	end
end
