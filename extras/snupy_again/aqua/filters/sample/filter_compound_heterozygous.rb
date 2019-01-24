class FilterCompoundHeterozygous < ComplexFilter
	create_filter_for QueryCompoundHeterozygous, :compound_heterozygous,
	                  name: :compound_heterozygous_vepensembl,
	                  label: "Compound Heterozygous filter (VEP)",
	                  filter_method: :compound_het_filter,
	                  collection_method: :find_samples,
	                  organism: [organisms(:human), organisms(:mouse)],
	                  checked: true,
	                  requires: {
		                  Vep::Ensembl => [:transcript_id]
	                  },
	                  tool: VepAnnotation
	
	# return a new array
	# arr: array of ungrouped records
	# values: Samples of parents
	#
	def compound_het_filter(arr, values, params)
		# collect variation ids
		variation_ids = arr.map{|rec| rec["variation_calls.variation_id"]}.sort.uniq
		varids2keep = _compound_heterozygous(values,
		                                     params,
		                                     Vep::Ensembl,
		                                     "transcript_id",
		                                     variation_ids,
		                                     {"#{Vep::Ensembl.aqua_table_alias}.canonical" => true})
		varids2keep = Hash[varids2keep.map{|varid| [varid.to_i, true]}]
		d "Keeping #{varids2keep.size} variants....".blue
		arr.select{|rec|
			#only keep records where the sample_id or specimen_id have another hit in the partner
			!varids2keep[rec['variation_calls.variation_id'].to_i].nil?
		}
	end
	
	def _compound_heterozygous(value, params, model, transcript_col, variation_ids = [], sql_where = "")
		assoc = Aqua.find_association(model, :variation_calls)
		mdltblname = model.table_name
		mdltblalias = (model.respond_to?(:aqua_table_alias))?(model.aqua_table_alias):(mdltblname)
		if assoc.nil?
			self.log_error("#{model.name} has no association to :variation_calls unable to find compound heterozygous SNVs")
			return nil
		end
		smplids = _reduce_to_accessible_samples(value, params["user"])
		# smpl_varcall = model.joins(:variation_calls)
		if smplids.size < 2 then
			self.class.log_info("Query can't be process, less than two samples")
			self.class.last_error("Query can't be process, less than two samples")
			return nil
		end
		
		#pp mdltblname
		#pp mdltblalias
		#pp smplids
		#pp transcript_col
		#pp sql_where
		#pp variation_ids[0..10]
		
		smpl_varcall = VariationCall.joins("INNER JOIN #{mdltblname} #{mdltblalias} ON (#{mdltblalias}.variation_id = variation_calls.variation_id)")
			               .where("variation_calls.sample_id" => smplids)
			               .where("variation_calls.variation_id" => variation_ids)
			               .where("variation_calls.gt" => ["0/1", "1|0", "0|1", "1/2", "1|2", "2|1"])
						   .where(sql_where)
			               .select(["variation_calls.variation_id", "variation_calls.sample_id", "#{mdltblalias}.#{transcript_col} AS ensembl_feature_id"])
		#self.class.last_error = "We stop here"
		#return []
		var2smpl2enst = Aqua.scope_to_array(smpl_varcall)
		enst2var2smpl = {}
		var2smpl2enst.each do |rec|
			enst2var2smpl[rec["ensembl_feature_id"]] ||= {}
			enst2var2smpl[rec["ensembl_feature_id"]][rec["variation_id"]] ||= []
			enst2var2smpl[rec["ensembl_feature_id"]][rec["variation_id"]] << rec["sample_id"]
		end
		enst2var2smpl.select!{|enst, var2smpl|
			# exclude variants that occur in both parents
			# then check if the transcript is still hit in two different transcripts
			var2smpl
				.select{|varid, smpls|
					smpls.uniq.size <= (smplids.size-1)
				}.values.flatten.uniq.size > 1
		}
		
		varids2retain = enst2var2smpl.map{|ent, var2smpl| var2smpl.keys}.flatten.uniq.sort
		varids2retain
	end
	
	def find_samples(params)
		exp = Experiment.find(params[:experiment])
		user = User.find(params[:user])
		exp_smpls = Hash[exp.samples.map{|s| [s.id, true]}]
		exp_smpls.default = false
		smpl_ids = (user.reviewable(Sample) + user.samples + exp.samples).map(&:id)
		smpls = Sample.where(id: smpl_ids)
			        .includes([:tags, :entity_group, :experiments, :institution, :entity => :tags, :specimen_probe => :tags, :vcf_file_nodata => :tags])
		smpls.sort!{|s1, s2|
			if exp_smpls[s1.id] && exp_smpls[s2.id] then
				s1.name <=> s2.name
			elsif exp_smpls[s1.id] || exp_smpls[s2.id]
				(exp_smpls[s1.id])?-1:1
			else
				s1.name <=> s2.name
			end
		}
		ret = smpls.map{|s|
			eg = (!s.entity_group.nil?)?(s.entity_group.name):("NA")
			ent = (!s.entity.nil?)?(s.entity.name):("NA")
			spec = (!s.specimen_probe.nil?)?(s.specimen_probe.name):("NA")
			smpl = s.name
			vcf = (!s.vcf_file_nodata.nil?)?(s.vcf_file_nodata.name):("NA")
			rec = {
				id: s.id,
				label: s.nickname,
				name: [eg, ent, spec, smpl, vcf].join("/")
			}
			rec["Entity.tags"] = (!s.entity.nil?)?(s.entity.tags.join(" | ")):("NA")
			rec["Specimen.tags"] = (!s.specimen_probe.nil?)?(s.specimen_probe.tags.join(" | ")):("NA")
			rec["Sample.tags"] = (!s.nil?)?(s.tags.join(" | ")):("NA")
			rec["VcfFile.tags"] = (!s.vcf_file_nodata.nil?)?(s.vcf_file_nodata.tags.join(" | ")):("NA")
			rec
		}
	end

end