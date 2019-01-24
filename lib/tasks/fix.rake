namespace :fix  do
	desc "Fix VarScan problems. 1) Reassign type to VCF File. 2) Add SOMATIC to info_matches so its reduced to SOMATIC. 6. Nov. 2014"
	task :varscan141106 => :environment do |t, args|
		# vcfids = VcfFile.select([:id, :name, :filename, :type]).all.select{|vcf|
		# 	vcf.name =~ /.*varscan.*/ or vcf.filename =~ /.*varscan.*/ or vcf.type == "VcfFileVarscan"  
		# }.map(&:id)
		vcfids = VcfFile.where("(name LIKE '%varscan%') OR (name LIKE 'varscan%') OR (name LIKE '%varscan') OR (type = 'VcfFileVarscan')").pluck(:id)
		puts "#{vcfids.size} VCF files affected"
		
		vcfids.each do |vcfid|
			smpls = Sample.where(vcf_file_id: vcfid)
			next unless smpls.size > 0
			puts "> Processing #{smpls.size} samples for #{VcfFile.select(:name).find(vcfid).name}..."
 			VcfFile.find(vcfid).update_attribute(:type, "VcfFileVarscan")
 			smpls.each do |smpl|
				print "	>> Processing #{smpl.name}..."
				if (smpl.info_matches.to_s == "") then
					print "fixed info_matches..."
					smpl.update_attribute(:info_matches, "SOMATIC")
				end
				print "refresh..."
				smpl.add_variation_calls
				print "DONE\n"
			end
		end
		
	end
end