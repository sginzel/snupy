namespace :sample_tags  do
	
	def get_status_mapping_deactive
		{
		"[1.0.0.0] - Unrelated Normal Control"	 => 	["CELLS", "control"],
		"[1.0.1.0] - Unrelated Normal Control,,Patient-derived Tissue,"	 => 	["COTHR", "control"], # maybe not satisifying
		"[1.0.2.0] - Unrelated Normal Control,,(Sorted) Primary cell population,"	 => 	["COTHR", "control", "sorted"],
		"[1.0.3.0] - Unrelated Normal Control,,Cell line,"	 => 	["CLINE", "control"],
		"[2.0.0.0] - Disease state-derived"	 => 	"INIT",
		"[2.1.0.0] - Disease state-derived,Malignant"	 => 	["INIT", "malignant"],
		"[2.1.1.0] - Disease state-derived,Malignant,Patient-derived tissue"	 => 	["INIT", "malignant"],
		"[2.1.1.1] - Disease state-derived,Malignant,Patient-derived tissue,Initial"	 => 	["INIT", "malignant"],
		"[2.1.1.2] - Disease state-derived,Malignant,Patient-derived tissue,Remission"	 => 	"REMI",
		"[2.1.1.3] - Disease state-derived,Malignant,Patient-derived tissue,Partial Remission"	 => 	["REMI", "partial"],
		"[2.1.1.4] - Disease state-derived,Malignant,Patient-derived tissue,Recurrent"	 => 	["RLPS", "malignant"],
		"[2.1.1.5] - Disease state-derived,Malignant,Patient-derived tissue,Control tissue"	 => 	"CNTRL",
		"[2.1.1.6] - Disease state-derived,Malignant,Patient-derived tissue,Other (e.g. after BMT..)"	 => 	"TREMI",
		"[2.1.2.0] - Disease state-derived,Malignant,(Sorted) Primary cell population"	 => 	["INIT", "sorted", "malignant"],
		"[2.1.2.1] - Disease state-derived,Malignant,(Sorted) Primary cell population,Initial"	 => 	["INIT", "sorted", "malignant"],
		"[2.1.2.2] - Disease state-derived,Malignant,(Sorted) Primary cell population,Remission"	 => 	["REMI", "sorted"],
		"[2.1.2.3] - Disease state-derived,Malignant,(Sorted) Primary cell population,Partial Remission"	 => 	["REMI", "partial", "sorted"],
		"[2.1.2.4] - Disease state-derived,Malignant,(Sorted) Primary cell population,Recurrent"	 => 	["RLPS", "sorted", "malignant"],
		"[2.1.2.5] - Disease state-derived,Malignant,(Sorted) Primary cell population,Control cells"	 => 	["CNTRL", "sorted"],
		"[2.1.2.6] - Disease state-derived,Malignant,(Sorted) Primary cell population,Other (e.g. after BMT....)"	 => 	["TRLPS", "sorted", "malignant"],
		"[2.1.3.0] - Disease state-derived,Malignant,Cell line"	 => 	["INIT", "malignant", "cellline"],
		"[2.1.3.1] - Disease state-derived,Malignant,Cell line,Virally tranformed"	 => 	["INIT", "cellline", "viral"],
		"[2.1.3.2] - Disease state-derived,Malignant,Cell line,Non-transformed"	 => 	["INIT", "cellline", "nontransformed"],
		"[2.2.0.0] - Disease state-derived,Immunedefect"	 => 	"INIT",
		"[2.2.1.0] - Disease state-derived,Immunedefect,Affected"	 => 	["INIT", "immunedefect"],
		"[2.2.1.1] - Disease state-derived,Immunedefect,Affected,Patient"	 => 	["INIT", "immunedefect"],
		"[2.2.1.2] - Disease state-derived,Immunedefect,Affected,Sibbling"	 => 	["CSBLNG", "immunedefect"],
		"[2.2.1.3] - Disease state-derived,Immunedefect,Affected,Mother"	 => 	["CPRNTS", "FMTHR", "immunedefect"],
		"[2.2.1.4] - Disease state-derived,Immunedefect,Affected,Father"	 => 	["CPRNTS", "FFTHR",  "immunedefect"],
		"[2.2.1.5] - Disease state-derived,Immunedefect,Affected,Other relatives"	 => 	["CPRNTS", "FOTHR",  "immunedefect"], # requires more
		"[2.2.2.0] - Disease state-derived,Immunedefect,Not-affected"	 => 	"GRML",
		"[2.2.2.1] - Disease state-derived,Immunedefect,Not-affected,Sibbling"	 => 	"CSBLNG",
		"[2.2.2.2] - Disease state-derived,Immunedefect,Not-affected,Mother"	 => 	["CPRNTS", "FMTHR"],
		"[2.2.2.3] - Disease state-derived,Immunedefect,Not-affected,Father"	 => 	["CPRNTS", "FFTHR"],
		"[2.2.2.4] - Disease state-derived,Immunedefect,Not-affected,Other relatives"	 => 	["CPRNTS", "FOTHR"],
		"[2.3.0.0] - Disease state-derived,Other"	 => 	"INIT",
		"[2.3.1.0] - Disease state-derived,Other,Affected"	 => 	"INIT",
		"[2.3.1.1] - Disease state-derived,Other,Affected,Patient"	 => 	"INIT",
		"[2.3.1.2] - Disease state-derived,Other,Affected,Sibbling"	 => 	"UNKNOWN", # #0 this cannot exist, it should be treated as a patient...
		"[2.3.1.3] - Disease state-derived,Other,Affected,Mother"	 => 	"UNKNOWN", # #0 this cannot exist, it should be treated as a patient...
		"[2.3.1.4] - Disease state-derived,Other,Affected,Father"	 => 	"UNKNOWN", # #0 this cannot exist, it should be treated as a patient...
		"[2.3.1.5] - Disease state-derived,Other,Affected,Other relatives"	 => 	"UNKNOWN", # #0 this cannot exist, it should be treated as a patient...
		"[2.3.2.0] - Disease state-derived,Other,Not-affected"	 => 	"UNKNOWN", #????COTH^$
		"[2.3.2.1] - Disease state-derived,Other,Not-affected,Sibbling"	 => 	["CSBLNG", "predispose"], #????
		"[2.3.2.2] - Disease state-derived,Other,Not-affected,Mother"	 => 	["CPRNTS", "FMTHR", "predispose"], #????
		"[2.3.2.3] - Disease state-derived,Other,Not-affected,Father"	 => 	["CPRNTS", "FFTHR", "predispose"], #????
		"[2.3.2.4] - Disease state-derived,Other,Not-affected,Other relatives"	 => 	["CPRNTS", "FOTHR", "predispose"] #????
		}
	end
	
	desc "Add new Sample Tags"
	task :add_tags => :environment do |t|
		# args.with_defaults(:file => nil)
		# fin = args[:file]
		
		stags = YAML.load(File.open(Rails.root.to_s + "/db/sample_tags_status.yaml", "r").read)
		dtags = YAML.load(File.open(Rails.root.to_s + "/db/sample_tags_disease.yaml", "r").read)
		ttags = YAML.load(File.open(Rails.root.to_s + "/db/sample_tags_tissue.yaml", "r").read)
		otags = YAML.load(File.open(Rails.root.to_s + "/db/sample_tags_other.yaml", "r").read)
		
		# Update existing sample tags to negative ids, so we can cope with them later.
		old_status_tags = SampleTag.where(tag_name: "STATUS").where(tag_type: "SAMPLE_HIERARCHY")
		old_status_tags.each do |st|
			if st.id < 10**7 then
				puts "backing up #{st.tag_value}"
				backitup(st)
			end
		end
		old_status_tags = SampleTag.where(tag_type: "STATUS").where(tag_type: "SAMPLE_HIERARCHY")
		
		# create new sample tags or update their ID if they already exists
		[stags, dtags, ttags, otags].flatten.each do |tag|
			st = SampleTag.find_by_tag_value(tag["tag_value"])
			if (!st.nil?)
				# puts "#{tag["tag_value"]} Updating ID"
				updateid(st, tag["id"])
			else
				st = SampleTag.find_by_id(tag["id"])
				if (!st.nil?) then
					# puts "#{tag["tag_value"]} not found, but #{tag["id"]} exists. Updating existing Sample Tag to negative ID - so we can deal with it later..."
					backitup(st)
					# puts "#{tag["tag_value"]} now we can create the new tag with #{tag["id"]}"
					newtag = SampleTag.create(tag)
					newtag.save
				else
					# puts "#{tag["tag_value"]} not found, will be created"
					newtag = SampleTag.create(tag)
					newtag.save
				end
				
			end
		end
		
	end

	desc "Add new Sample Tags"
	task :update_relations => :environment do |t|
		# args.with_defaults(:file => nil)
		# fin = args[:file]
		mapping = get_status_mapping
		stags = YAML.load(File.open(Rails.root.to_s + "/db/sample_tags_status.yaml", "r").read)
		dtags = YAML.load(File.open(Rails.root.to_s + "/db/sample_tags_disease.yaml", "r").read)
		ttags = YAML.load(File.open(Rails.root.to_s + "/db/sample_tags_tissue.yaml", "r").read)
		otags = YAML.load(File.open(Rails.root.to_s + "/db/sample_tags_other.yaml", "r").read)
		
		mapping = get_status_mapping.map{|oldtag, newtags|
			oldsmpltag = SampleTag.find_by_tag_value(oldtag)
			newsmpltag = SampleTag.where(tag_value: newtags)
			if newsmpltag.size != newtags.size then
				pp oldtag
				pp newtags
				pp newsmpltag
				raise "not all tags found for mapping"
			end
		}
		
	end
	
	def backitup(smpltag)
		# puts "setting of #{smpltag} to negative" 
		updateid(smpltag, smpltag.id + 10**7)
	end
	
	def updateid(smpltag, newid)
		puts "Updating sample_tag ID #{smpltag.id} => #{newid}"
		exists = SampleTag.find_by_id(newid)
		if (!exists.nil?) then
			raise "SampleTag with id #{exists.tag_value} already exists. You messed up boy."
		end
		oldid = smpltag.id
		smpltag.id = newid
		if (smpltag.save)
			# puts "Updating relationship"
			ActiveRecord::Base.connection.execute("UPDATE sample_has_sample_tag SET sample_tag_id = #{smpltag.id} WHERE sample_tag_id = #{oldid}")
		else
			raise "#{smpltag} couldnt be saved."
		end
		smpltag
	end
	
	
end