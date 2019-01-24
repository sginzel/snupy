module SampleCreateFromSampleSheetHelper
	# we cannot redirect to a single sample when we created a bunch of them at once...
	def create_from_sample_sheet
		# create a template to call Sample.new
		template = {}
		%w(name patient notes contact gender ignorefilter sample_type min_read_depth info_matches nickname filters).each do |attr|
			template[attr] = (params[:sample] || {})[attr]
		end

		# parse sample sheet
		if !params[:sample][:sample_sheet].is_a?(Array) then
			@sample_sheet = params[:sample][:sample_sheet].read.split("\n").map{|line| line.split("\t")}
		else
			@sample_sheet = params[:sample][:sample_sheet].map{|line| line.split("\t")}
		end

		header = @sample_sheet.delete_at(0)
		@sample_sheet.map!{|rec|
			Hash[header.each_with_index.map{|colname, recidx| [colname, rec[recidx]]}]
		}

		allowed_fields = {
				"vcf_file_id" => true,
				"vcf_sample_name" => true,
				"name" => true,
				"patient" => true,
				"notes" => true,
				"contact" => true,
				"gender" => true,
				"ignorefilter" => true,
				"sample_type" => true,
				"min_read_depth" => true,
				"info_matches" => true,
				"nickname" => true,
				"filters" => true,
				"project" => true,
				"specimen_probe_id" => true,
				"specimen_probe_name" => true
		}
		# allowed_fields.keys.each{|k| allowed_fields[k.to_sym] = true}
		allowed_fields.default(false)
#		base_tags = (params[:tags] || {}).map{|category, tagid|
#			Tag.find(tagid)
#		}.flatten
#		base_tags = [] if base_tags.nil?
		tags = []
		@sample_sheet.each do |smpldesc|
			sattrs = template.dup
			sattrs = sattrs.merge(smpldesc.select{|k,v| allowed_fields[k]})

			# when ignore filter value is 2, then we only want to use PASS
			if (sattrs["ignorefilter"] == "2") then
				sattrs["filters"] = "PASS"
				sattrs["ignorefilter"] = "0"
			end

			existing_smpl = Sample.find_by_vcf_file_id_and_vcf_sample_name(sattrs["vcf_file_id"], sattrs["vcf_sample_name"])

			if existing_smpl.nil? then
				# check if the VcfFile is Ready for extraction?
				vcf = VcfFile.select([:id, :status, :sample_names, :filters]).find(sattrs["vcf_file_id"])
				if vcf.nil? or vcf.status != :DONE then
					smpldesc[:error] = "VCF File is not ready for import."
					smpldesc[:sample] = nil
					next
				end
				vcf_samples = vcf.get_sample_names
				vcf_filters = YAML.load(vcf.filters).keys

				# check if selected sample name is valid
				if !vcf_samples.include?(sattrs["vcf_sample_name"]) then
					smpldesc[:error] = "VCF sample name #{sattrs["vcf_sample_name"]} not found in #{vcf_samples.join(",")}"
					smpldesc[:sample] = nil
					next
				end

				# check if all filters are valid
				if !sattrs["filters"].split(",").all?{|fval| vcf_filters.include?(fval)}
					smpldesc[:error] = "Not all given filters #{sattrs["filters"]} available in VcfFile #{vcf_filters.join(",")}"
					smpldesc[:sample] = nil
					next
				end

				experiments = sattrs.delete("project")
				experiments = nil if experiments.to_s.strip == ""
				sattrs["specimen_probe_id"] = nil if sattrs["specimen_probe_id"].to_s.strip == ""
				sattrs["specimen_probe_name"] = nil if sattrs["specimen_probe_name"].to_s.strip == ""
				# if the specimen_probe_id is a name then we set the specimen_probe name
				if (!sattrs["specimen_probe_id"].to_s.strip =~ /^[0-9]+$/) and sattrs["specimen_probe_id"].to_s.strip.size > 0
					sattrs["specimen_probe_name"] = sattrs["specimen_probe_id"]
					sattrs["specimen_probe_id"] = nil
				end
				# try to find the correct specimen by name if provided
				if not sattrs["specimen_probe_name"].nil? then
					if sattrs["specimen_probe_id"].nil? then
						specs = SpecimenProbe.where(name: (sattrs["specimen_probe_name"] || sattrs["specimen_probe_id"]))
						if (sattrs["project"].to_s != "") then
							exps = Experiment.where("title = '#{sattrs["project"]}' OR name = '#{sattrs["project"]}' OR id = '#{sattrs["project"]}' AND id > 0")
							if (exps.count == 1) then
								specs = SpecimenProbe.joins(:experiments).where("experiments.id" => exps.pluck(:id)).where(name: (sattrs["specimen_probe_name"] || sattrs["specimen_probe_id"]))
								if specs.size == 0 then
									specs = SpecimenProbe.where(name: (sattrs["specimen_probe_name"] || sattrs["specimen_probe_id"]))
								end
							end
						end
						if specs.size == 1 then
							sattrs["specimen_probe_id"] = specs.first.id
						elsif specs.size == 0 then
							d "No specimen found '#{sattrs["specimen_probe_name"]}' or '#{sattrs["specimen_probe_id"]}'"
							smpldesc[:error] = 'Specimen not identified by name. Provide an ID if possible.'
							smpldesc[:sample] = nil
							next
						else
							d "Too many specimen found '#{sattrs["specimen_probe_name"]}' or '#{sattrs["specimen_probe_id"]}'"
							smpldesc[:error] = 'Specimen name not specific. Provide an ID if possible, maybe a project can also help.'
							smpldesc[:sample] = nil
							next
						end
					end
					sattrs.delete("specimen_probe_name")
				end
				
				sample = Sample.new(sattrs)
				sample.status = "ENQUEUED"
				#status_tags = SampleTag.find_all_by_tag_value(smpldesc["status_tag"].split(";"))
				#tissue_tags = SampleTag.find_all_by_tag_value(smpldesc["tissue_tag"].split(";"))
				#disease_tags = SampleTag.find_all_by_tag_value(smpldesc["disease_tag"].split(";"))
				sheet_tags = JSON.parse(smpldesc["tags"] || {}.to_json)
				if sheet_tags.size > 0 then
					tags = sheet_tags.map{|category, values|
						values = [values] unless values.is_a?(Array)
						Tag.where(category: category).where(object_type: "Sample").where(value: values)
					}.reject{|x| x.nil?}.flatten
				else
					tags = sheet_tags.dup
				end

				users = User.find_all_by_name(smpldesc["users"].split(";"))
				sample.users = users

				if sample.vcf_file_id.nil? or sample.vcf_sample_name.nil? then
					smpldesc[:error] = "No VcfFileID or VcfSampleName given."
					smpldesc[:sample] = nil
					next
				end

				sample.tags = tags
				d "xxxxxxxxxxxxxxxxxxxxxxxxxx"
				d smpldesc
				d "++++++++++++++++++"
				d sample.attributes
				d "++++++++++++++++++"
				d sample.specimen_probe_id
				d "----------------"
				if sample.save
					# sample.sample_tags = [status_tags, tissue_tags, disease_tags].flatten
					# sample.users = users
					notice = "Sample created, variation calls will be available soon."
					# sample.status = "ENQUEUED"
					# sample.save!
					smpldesc[:sample] = sample
					smpldesc[:long_job] = LongJob.create_job({
																											 title: "Extract #{sample.name}",
																											 handle: sample,
																											 method: :add_variation_calls,
																											 user: http_remote_user(),
																											 queue: "annotation"
																									 }, false)
					if !experiments.nil? then
						notice += "Sample added to projects: "
						Experiment.where(id: experiments.split(";")).each do |exp|
							exp.samples << sample
							exp.save
							notice += " #{(exp.name ||exp.title)}"
						end
					else
						notice += "Sample was not linked to a project."
					end
					smpldesc[:notice] = notice
				else
					smpldesc[:sample] = sample
					smpldesc[:error] = "Sample could not be saved."
					smpldesc[:notice] = ""
				end
			else
				smpldesc[:error] = "Sample already exists. Not able to mass-modify or mass-recreate samples."
				smpldesc[:sample] = existing_smpl
				smpldesc[:notice] = ""
			end
		end

		@result = []
		@sample_sheet.each do |smpldesc|
			if not smpldesc[:sample].nil? then
				@result << {
						id: smpldesc[:sample].id,
						sampleID: smpldesc[:sample].id,
						name: smpldesc[:sample].name,
						nickname: smpldesc[:sample].nickname,
						specimen: (smpldesc[:sample].specimen_probe || SpecimenProbe.new).name || (ActionController::Base.helpers.link_to "ASSIGN TO SPECIMEN", samples_path(ids:smpldesc[:sample])),
						patient: smpldesc[:sample].patient,
						vcf_file_id: smpldesc[:sample].vcf_file_id,
						vcf_sample_name: smpldesc[:sample].vcf_sample_name,
						tags: smpldesc[:sample].tags.map{|tag| tag.value}.join(", "),
						users: smpldesc[:sample].users.map{|user| user.name}.join(", "),
						job: (smpldesc[:long_job].nil?)?"":smpldesc[:long_job].title,
						status: smpldesc[:sample].status,
						error: smpldesc[:error].to_s,
						notice: smpldesc[:notice].to_s,
				}
			else
				@result << {
						id: "",
						sampleID: "",
						name: smpldesc["name"],
						nickname: smpldesc["nickname"],
						specimen: smpldesc["specimen_probe_id"],
						patient: smpldesc["patient"],
						vcf_file_id: smpldesc["vcf_file_id"],
						vcf_sample_name: smpldesc["vcf_sample_name"],
						tags: (tags || []).map(&:value).join(", "),
						users: smpldesc["users"],
						job: "",
						status: "",
						error: smpldesc[:error].to_s,
						notice: notice
				}
			end
		end

		respond_to do |format|
			format.html { render "samples/create_from_sample_sheet"}
			format.json { render json: @sample_sheet }
		end
	end
end