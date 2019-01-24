class FilterSample < SimpleFilter
	create_filter_for QuerySample, :present_in_any,
						name: :present_in_any_gq75, 
						label: "Present in any (genotype quality > 75)",
						filter_method: lambda{|value, params| present_in_any_gq_gt(value, params, gq = 75, gt = nil)},
						collection_method: :find_samples,
						organism: [organisms(:human), organisms(:mouse)],
						checked: true, 
						requires: {},
						tool: Annotation
	create_filter_for QuerySample, :present_in_any,
						name: :present_in_any_gp0, 
						label: "Present in any",
						filter_method: lambda{|value, params| present_in_any_gq_gt(value, params, gq = nil, gt = nil)},
						collection_method: :find_samples,
						organism: [organisms(:human), organisms(:mouse)],
						checked: false, 
						requires: {},
						tool: Annotation
	create_filter_for QuerySample, :present_in_all,
						name: :present_in_all_gq75, 
						label: "Present in all (genotype quality > 75)",
						filter_method: lambda{|value, params| present_in_all_gq_gt(value, params, gq = 75, gt = nil)},
						collection_method: :find_samples,
						organism: [organisms(:human), organisms(:mouse)],
						checked: true, 
						requires: {},
						tool: Annotation
	create_filter_for QuerySample, :present_in_all,
						name: :present_in_all_gp0, 
						label: "Present in any",
						filter_method: lambda{|value, params| present_in_all_gq_gt(value, params, gq = nil, gt = nil)},
						collection_method: :find_samples,
						organism: [organisms(:human), organisms(:mouse)],
						checked: false, 
						requires: {},
						tool: Annotation
	
	create_filter_for QuerySample, :not_present_in_any,
						name: :not_present_in_gq,
						label: "Not present in (genotype quality > 75)",
						filter_method: :not_present_in_gq,
						collection_method: :find_samples,
						organism: [organisms(:human), organisms(:mouse)],
						checked: true, 
						requires: {},
						tool: Annotation
	create_filter_for QuerySample, :not_present_in_any,
						name: :not_present_in,
						label: "Not present in",
						filter_method: :not_present_in,
						collection_method: :find_samples,
						organism: [organisms(:human), organisms(:mouse)],
						checked: false,  
						requires: {},
						tool: Annotation
						
	create_filter_for QuerySample, :heterozygous_in_all,
						name: :heterozygous_all_gq75,
						label: "Genotype quality > 75",
						filter_method: lambda{|value, params| present_in_all_gq_gt(value, params, gq = 75, gt = ["0/1", "1/0", "0|1", "1|0", "1/2", "2/1", "1|2", "2|1"])},
						collection_method: :find_samples,
						organism: [organisms(:human), organisms(:mouse)],
						checked: true, 
						requires: {},
						tool: Annotation
	create_filter_for QuerySample, :heterozygous_in_all,
						name: :heterozygous_all_gq0,
						label: "Any genotype quality",
						filter_method: lambda{|value, params| present_in_all_gq_gt(value, params, gq = nil, gt = ["0/1", "1/0", "0|1", "1|0", "1/2", "2/1", "1|2", "2|1"])},
						collection_method: :find_samples,
						organism: [organisms(:human), organisms(:mouse)],
						checked: false, 
						requires: {},
						tool: Annotation
						
	create_filter_for QuerySample, :heterozygous_in_any,
						name: :heterozygous_any_gq75,
						label: "Genotype quality > 75",
						filter_method: lambda{|value, params| present_in_any_gq_gt(value, params, gq = 75, gt = ["0/1", "1/0", "0|1", "1|0", "1/2", "2/1", "1|2", "2|1"])},
						collection_method: :find_samples,
						organism: [organisms(:human), organisms(:mouse)],
						checked: true, 
						requires: {},
						tool: Annotation
	create_filter_for QuerySample, :heterozygous_in_any,
						name: :heterozygous_any_gq0,
						label: "Any genotype quality",
						filter_method: lambda{|value, params| present_in_any_gq_gt(value, params, gq = nil, gt = ["0/1", "1/0", "0|1", "1|0", "1/2", "2/1", "1|2", "2|1"])},
						collection_method: :find_samples,
						organism: [organisms(:human), organisms(:mouse)],
						checked: false, 
						requires: {},
						tool: Annotation
						
	create_filter_for QuerySample, :homozygous_in_all,
						name: :homozygous_in_all_gq75,
						label: "Genotype quality > 75",
						filter_method: lambda{|value, params| present_in_all_gq_gt(value, params, gq = 75, gt = ["1/1", "1|1", "2/2", "2|2"])},
						collection_method: :find_samples,
						organism: [organisms(:human), organisms(:mouse)],
						checked: true,  
						requires: {},
						tool: Annotation
	create_filter_for QuerySample, :homozygous_in_all,
						name: :homozygous_in_all_gq0,
						label: "Any genotype quality",
						filter_method: lambda{|value, params| present_in_all_gq_gt(value, params, gq = nil, gt = ["1/1", "1|1", "2/2", "2|2"])},
						collection_method: :find_samples,
						organism: [organisms(:human), organisms(:mouse)],
						checked: false,  
						requires: {},
						tool: Annotation
						
	create_filter_for QuerySample, :homozygous_in_any,
						name: :homozygous_in_any_gq75,
						label: "Genotype quality > 75",
						filter_method: lambda{|value, params| present_in_any_gq_gt(value, params, gq = 75, gt = ["1/1", "1|1", "2/2", "2|2"])},
						collection_method: :find_samples,
						organism: [organisms(:human), organisms(:mouse)],
						checked: true,  
						requires: {},
						tool: Annotation
	create_filter_for QuerySample, :homozygous_in_any,
						name: :homozygous_in_any_gq0,
						label: "Any genotype quality",
						filter_method: lambda{|value, params| present_in_any_gq_gt(value, params, gq = nil, gt = ["1/1", "1|1", "2/2", "2|2"])},
						collection_method: :find_samples,
						organism: [organisms(:human), organisms(:mouse)],
						checked: false,  
						requires: {},
						tool: Annotation
	
	# This compound heterozygous filter is not correct. It has to be complex and the last in the query chain
	#create_filter_for QuerySample, :compound_heterozygous,
	#					name: :compound_heterozygous_snpeff,
	#					label: "Compound heterozygous (SNPEff)",
	#					filter_method: :compound_heterozygous_snpeff,
	#					collection_method: :find_samples,
	#					organism: [organisms(:human), organisms(:mouse)],
	#					checked: false,
	#					requires: {
	#						SnpEff => [:ensembl_feature_id]
	#					},
	#					tool: SnpEffAnnotation
	
	#create_filter_for QuerySample, :compound_heterozygous,
	#					name: :compound_heterozygous_annovar,
	#					label: "Compound heterozygous (AnnoVar)",
	#					filter_method: :compound_heterozygous_annovar,
	#					collection_method: :find_samples,
	#					organism: [organisms(:human), organisms(:mouse)],
	#					checked: false,
	#					requires: {
	#						Annovar => [:ensembl_effect_transcript]
	#					},
	#					tool: AnnovarAnnotation
						
	#create_filter_for QuerySample, :compound_heterozygous,
	#					name: :compound_heterozygous_vepensembl,
	#					label: "Compound heterozygous (Vep Ensembl)",
	#					filter_method: :compound_heterozygous_vep_ensembl,
	#					collection_method: :find_samples,
	#					organism: [organisms(:human), organisms(:mouse)],
	#					checked: true,
	#					requires: {
	#						Vep::Ensembl => [:transcript_id]
	#					},
	#					tool: VepAnnotation
	
	#create_filter_for QuerySample, :compound_heterozygous,
	#					name: :compound_heterozygous_veprefseq,
	#					label: "Compound heterozygous (VEP RefSeq)",
	#					filter_method: :compound_heterozygous_vep_refseq,
	#					collection_method: :find_samples,
	#					organism: [organisms(:human), organisms(:mouse)],
	#					checked: false,
	#					requires: {
	#						Vep::RefSeq => [:transcript_id]
	#					},
	#					tool: VepAnnotation
	
	create_filter_for QuerySample, :baf_difference_gt,
						name: :baf_difference_gt_25,
						label: "Abs. BAF difference > 25%",
						filter_method: :baf_difference_gt_25,
						collection_method: :find_samples,
						organism: [organisms(:human), organisms(:mouse)], 
						checked: false, 
						requires: {
							VariationCall => [:alt_reads, :ref_reads]
						},
						tool: Annotation
	create_filter_for QuerySample, :baf_difference_gt,
						name: :baf_difference_gt_40,
						label: "Abs. BAF difference > 40%",
						filter_method: :baf_difference_gt_40,
						collection_method: :find_samples,
						organism: [organisms(:human), organisms(:mouse)],
						checked: true,
						requires: {
							VariationCall => [:alt_reads, :ref_reads]
						},
						tool: Annotation
	create_filter_for QuerySample, :baf_difference_gt,
						name: :baf_difference_gt_50,
						label: "Abs. BAF difference > 50%",
						filter_method: :baf_difference_gt_50,
						collection_method: :find_samples,
						organism: [organisms(:human), organisms(:mouse)],
						checked: false,
						requires: {
							VariationCall => [:alt_reads, :ref_reads]
						},
						tool: Annotation
	create_filter_for QuerySample, :baf_difference_gt,
						name: :baf_difference_gt_75,
						label: "Abs. BAF difference > 75%",
						filter_method: :baf_difference_gt_75,
						collection_method: :find_samples,
						organism: [organisms(:human), organisms(:mouse)], 
						checked: false, 
						requires: {
							VariationCall => [:alt_reads, :ref_reads]
						},
						tool: Annotation
	
	create_filter_for QuerySample, :not_present_in_any_other,
						name: :not_present_in_any_other,
						label: "Genotype quality > 75",
						filter_method: :not_present_in_any_other,
						organism: [organisms(:human), organisms(:mouse)],
						checked: true, 
						requires: {},
						tool: Annotation
	
	create_filter_for QuerySample, :present_in_at_least_sample,
						name: :present_in_at_least_sample_gq0,
						label: "Present in at least X samples",
						filter_method: :present_in_at_least_samples,
						organism: [organisms(:human), organisms(:mouse)],
						checked: true, 
						requires: {},
						tool: Annotation
create_filter_for QuerySample, :present_in_at_least_patient,
						name: :present_in_at_least_sample_gq0,
						label: "Present in at least X patients",
						filter_method: :present_in_at_least_patient,
						organism: [organisms(:human), organisms(:mouse)],
						checked: true, 
						requires: {},
						tool: Annotation

	create_filter_for QuerySample, :query_design,
						name: :query_design, 
						label: "Input SampleIds, output variation calls",
						filter_method: :query_design,
						organism: [organisms(:human), organisms(:mouse)],
						checked: true,
						requires: {},
						tool: Annotation
	create_filter_for QuerySample, :query_design_not,
						name: :query_design_not, 
						label: "Input SampleIds, output variation calls",
						filter_method: :query_design_not,
						organism: [organisms(:human), organisms(:mouse)],
						checked: true, 
						requires: {},
						tool: Annotation

	create_filter_for QuerySample, :query_design,
										name: :query_design_variation,
										label: "Input SampleIds, output variations",
										filter_method: :query_design_variation,
										organism: [organisms(:human), organisms(:mouse)],
										checked: false,
										requires: {},
										tool: Annotation
	create_filter_for QuerySample, :query_design_not,
										name: :query_design_variation_not,
										label: "Input SampleIds, output variations",
										filter_method: :query_design_variation_not,
										organism: [organisms(:human), organisms(:mouse)],
										checked: false,
										requires: {},
										tool: Annotation
						
	def query_design(value, params)
		# parse the samples
		vcids = SnupyAgain::SampleSet.parse(value.gsub("\n", "").gsub("\r", "")).variation_call_ids.flatten
		return _variation_call_id_in(vcids)
	end
	
	def query_design_not(value, params)
		# parse the samples
		vcids = SnupyAgain::SampleSet.parse(value.gsub("\n", "").gsub("\r", "")).variation_call_ids.flatten
		return _variation_call_id_in(vcids, true)
	end

	def query_design_variation(value, params)
		# parse the samples
		varids = SnupyAgain::SampleSet.parse(value.gsub("\n", "").gsub("\r", "")).varids.flatten.uniq
		return _variation_id_in(varids)
	end

	def query_design_variation_not(value, params)
		# parse the samples
		varids = SnupyAgain::SampleSet.parse(value.gsub("\n", "").gsub("\r", "")).varids.flatten.uniq
		return _variation_id_in(varids, true)
	end
	
	def not_present_in_gq(value, params)
		_not_present_in(value, params, 75)
	end
	def not_present_in(value, params)
		_not_present_in(value, params, 0)
	end
	# Timeing test with 1 sample vs approx. 40 othes
	#  using LEFT JOIN, 970 sec -> 6945 ids
	## SELECT COUNT(id) FROM snupy_aqua.variation_calls where
	## sample_id = 47 AND variation_id IN(
	## 	SELECT vc1.variation_id
	## 		FROM snupy_aqua.variation_calls vc1
	## 		LEFT JOIN snupy_aqua.variation_calls vc2 ON (vc1.variation_id = vc2.variation_id AND vc2.gq > 75 AND vc2.sample_id IN (61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100))
	## 		WHERE
	## 		vc1.sample_id IN(47) 
	## 		 AND vc2.variation_id IS NULL
	## 		ORDER BY vc1.variation_id
	## ) 
	#  using NOT EXISTS 202 sec -> 6945 ids
	## SELECT COUNT(id) FROM snupy_aqua.variation_calls where
	## sample_id = 47 AND NOT EXISTS (
	## 	SELECT variation_id
	## 		FROM variation_calls vc 
	## 		WHERE
	## 		vc.variation_id IS NOT NULL AND
	## 		vc.variation_id = variation_calls.variation_id AND
	## 		vc.gq > 75 AND 
	## 		vc.sample_id IN (61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100)
	## )
	#  using NOT in, 198 sec -> 6945 ids
	## SELECT COUNT(id) FROM snupy_aqua.variation_calls where
	## sample_id = 47 AND variation_id NOT IN(
	## SELECT vc1.variation_id
	## FROM snupy_aqua.variation_calls vc1
	## 	WHERE
	## 	vc1.gq > 75 AND 
	## 	vc1.sample_id IN (61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100)
	## 	ORDER by vc1.variation_id
	## )

	def _not_present_in(value, params, gq)
		#if value.size > 200
		#	self.log_error("NOT present in Filter not allowed for more than 200 samples.")
		#	return nil
		#end
		smplids = _reduce_to_accessible_samples(value, params["user"])
		return <<EOS
variation_calls.variation_id NOT IN(
	SELECT vc1.variation_id
	FROM variation_calls vc1
	WHERE
	vc1.gq >= #{gq} AND 
	vc1.sample_id IN (#{smplids.join(",")})
	ORDER by vc1.variation_id
	)
EOS
	end
	
	def present_in_at_least_samples(value, params)
		return "" if value.to_i <= 1 # return nothing in case the user parameters are useless, because he had to select samples anyway
		smplids = params["samples"]
		return nil if value.to_i > smplids.size
		"variation_calls.variation_id IN (
			SELECT vcatleast.variation_id FROM variation_calls vcatleast WHERE 
			vcatleast.sample_id IN (#{smplids.join(",")}) 
			GROUP BY vcatleast.variation_id
			HAVING COUNT(vcatleast.sample_id) >= #{value}
			ORDER BY vcatleast.variation_id
		)"
	end
	
	def present_in_at_least_patient(value, params)
		return "" if value.to_i <= 1
		smplids = params["samples"]
		patients = Sample.where(id: smplids).pluck(:patient)
		return nil if value.to_i > patients.uniq.size
		"variation_calls.variation_id IN (
			SELECT vcatleast.variation_id 
			FROM variation_calls vcatleast
			INNER JOIN samples vcatsmpl ON (vcatleast.sample_id = vcatsmpl.id) 
			WHERE 
			vcatleast.sample_id IN (#{smplids.join(",")}) 
			GROUP BY vcatleast.variation_id
			HAVING COUNT(vcatsmpl.patient) >= #{value}
			ORDER BY vcatleast.variation_id
		)"
	end
	
	def present_in_all_gq_gt(value, params, gq = 75, gt = nil)
		smplids = _reduce_to_accessible_samples(value, params["user"])
		return nil if smplids.size == 0
		gtcond = ""
		gqcond = ""
		havecond = ""
		gtcond = "AND gt IN (#{gt.map{|x| "'#{x}'"}.join(", ")})" unless gt.nil?
		gqcond = "AND gq >= #{gq.to_f}" unless gq.nil?
		havecond = "
			GROUP BY vchetall.variation_id
			HAVING COUNT(vchetall.id) = #{smplids.size}" if smplids.size > 1
		return <<EOS
		variation_calls.variation_id IN (
			SELECT vchetall.variation_id FROM variation_calls vchetall WHERE 
			sample_id IN (#{smplids.join(",")}) 
			#{gtcond}
			#{gqcond}
			#{havecond}
			ORDER BY vchetall.variation_id
		)
EOS
	end
	
	def present_in_any_gq_gt(value, params, gq = 75, gt = nil)
		smplids = _reduce_to_accessible_samples(value, params["user"])
		return nil if smplids.size == 0
		gtcond = ""
		gqcond = ""
		havecond = ""
		gtcond = "AND gt IN (#{gt.map{|x| "'#{x}'"}.join(", ")})" unless gt.nil?
		gqcond = "AND gq >= #{gq.to_f}" unless gq.nil?
		return <<EOS
			variation_calls.variation_id IN (
				SELECT variation_id 
				FROM variation_calls vcall
				WHERE vcall.sample_id IN (#{smplids.join(",")}) 
				#{gtcond}
				#{gqcond} 
				ORDER BY variation_id)
EOS
	end
	
	def compound_heterozygous_snpeff(value, params)
		_compound_heterozygous(value, params, SnpEff, :ensembl_feature_id,
		{"snp_effs.annotation" => ['disruptive_inframe_deletion', 'disruptive_inframe_insertion', 
			'frameshift_variant', 'inframe_deletion', 'inframe_insertion', 
			'initiator_codon_variant', 'missense_variant', 'non_canonical_start_codon', 
			'non_coding_exon_variant', 'rare_amino_acid_variant', 
			'splice_acceptor_variant', 'splice_donor_variant', 'start_lost', 
			'stop_gained', 'stop_lost', 'TF_binding_site_variant']}
		)
	end
	def compound_heterozygous_annovar(value, params)
		_compound_heterozygous(value, params, Annovar, :ensembl_effect_transcript,
		{
			"annovars.ensembl_annotation" => ['frameshift_elongation', 'inframe_deletion', 
				'inframe_insertion', 'missense_variant', 'splice_region_variant', 
				'stop_gained', 'stop_lost']
		})
	end
	def compound_heterozygous_vep_ensembl(value, params)
		_compound_heterozygous(value, params, Vep::Ensembl, :transcript_id,
		{
			Vep::Ensembl.colname("consequence") => ['frameshift_variant', 'incomplete_terminal_codon_variant', 
				'inframe_deletion', 'inframe_insertion', 'missense_variant', 
				'protein_altering_variant', 'splice_acceptor_variant', 
				'splice_donor_variant', 'start_lost', 'stop_gained', 'stop_lost', 
				'TFBS_ablation', 'TF_binding_site_variant']
		})
	end
	def compound_heterozygous_vep_refseq(value, params)
		_compound_heterozygous(value, params, Vep::RefSeq, :transcript_id,
		{
			Vep::RefSeq.colname("consequence") => ['frameshift_variant', 'incomplete_terminal_codon_variant', 
				'inframe_deletion', 'inframe_insertion', 'missense_variant', 
				'protein_altering_variant', 'splice_acceptor_variant', 
				'splice_donor_variant', 'start_lost', 'stop_gained', 'stop_lost', 
				'TFBS_ablation', 'TF_binding_site_variant']
		})
	end
	def _compound_heterozygous(value, params, model, transcript_col, consequences)
		assoc = Aqua.find_association(model, :variation_calls)
		mdltblname = model.table_name
		mdltblalias = (model.respond_to?(:aqua_table_alias))?(model.aqua_table_alias):(mdltblname) 
		if assoc.nil? 
			self.log_error("#{model.name} has no association to :variation_calls unable to find compound heterozygous SNVs")
			return nil
		end
		smplids = _reduce_to_accessible_samples(value, params["user"])
		# smpl_varcall = model.joins(:variation_calls)
		return nil if smplids.size < 2
		
		smpl_varcall = VariationCall.joins("INNER JOIN #{mdltblname} #{mdltblalias} ON (#{mdltblalias}.variation_id = variation_calls.variation_id)")
										.where("variation_calls.sample_id" => smplids)
										.where(consequences)
										.select(["variation_calls.variation_id", "variation_calls.sample_id", "#{mdltblalias}.#{transcript_col} AS ensembl_feature_id"])
										.where("variation_calls.gt" => ["0/1", "1|0", "0|1", "1/2", "1|2", "2|1"])

		#smpl_varcall = VariationCall
		#								.joins(variation_annotations: [:genetic_element])
		#								.where(sample_id: smplids)
		#								.select(["variation_calls.variation_id", :sample_id, :ensembl_feature_id])
		#								# .where(gt: ["0/1", "1|0", "0|1", "1/2", "1|2", "2|1"]) # genotype of parents should not matter
		
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
		if varids2retain.size == 0 then
			return nil
		else
			# "variation_calls.variation_id IN (#{varids2retain.join(",")})"
			_variation_id_in(varids2retain)
		end
		
	end
	
	def baf_difference_gt(threshold, value, params)
		smplids = _reduce_to_accessible_samples(value, params["user"])
		var2baf = VariationCall
								.where(sample_id: smplids + params["samples"])
								.select([:variation_id, :sample_id, :ref_reads, :alt_reads])
		var2baf = Aqua.scope_to_array(var2baf)
		var2smpl2baf = {}
		var2baf.each do |rec|
			var2smpl2baf[rec["variation_id"]] ||= {}
			baf = (rec["alt_reads"].to_f) / (rec["alt_reads"].to_f + rec["ref_reads"].to_f) 
			var2smpl2baf[rec["variation_id"]][rec["sample_id"]] = baf
		end
		
		vars2retain = []
		selected_samples = params["samples"].map(&:to_i)
		filtered_samples  = smplids.map(&:to_i)
		var2smpl2baf.each do |varid, smpl2baf|
			selected_sample_baf_max = (selected_samples.map{|sid| smpl2baf[sid]}.reject(&:nil?).max  || 0) # default BAF is 0 
			filtered_sample_baf_min  = (filtered_samples.map{|sid| smpl2baf[sid]}.reject(&:nil?).min || (selected_sample_baf_max - threshold)) # this way a variant is retained if its not present in the filtered sample but in the selected samples
			vars2retain << varid if (selected_sample_baf_max - filtered_sample_baf_min).abs >= threshold
		end
		
		return nil if vars2retain.size == 0
		# "variation_calls.variation_id IN (#{vars2retain.sort.join(",")})"
		_variation_id_in(vars2retain)
	end
	
	def baf_difference_gt_25(value, params)
		baf_difference_gt(0.25, value, params)
	end
	
	def baf_difference_gt_40(value, params)
		baf_difference_gt(0.4, value, params)
	end
	
	def baf_difference_gt_50(value, params)
		baf_difference_gt(0.5, value, params)
	end
	
	def baf_difference_gt_75(value, params)
		baf_difference_gt(0.75, value, params)
	end
	
	def not_present_in_any_other(value, params, gq = 75)
		org = Sample.where(id: params["samples"]).first.organism.id
		smpl_varids = VariationCall.where(sample_id: (params["samples"] || params[:samples] || [])).where("gq >= #{gq.to_f}").pluck("variation_id").uniq.sort
		smpl_org = Sample.joins(:organism).where("organisms.id" => org).pluck("samples.id")
		isSelectedSample = Hash[(params["samples"] || params[:samples] || []).map{|x| [x.to_i, true]}]
		varHasOther = Hash[smpl_varids.map{|x| [x, false]}]
		smpl_varids.each_slice(1000) do |varids|
			Aqua.scope_to_array(VariationCall
			.where(variation_id: varids)
			.where(sample_id: smpl_org)
			.where("gq >= #{gq.to_f}")
			.select([:variation_id, :sample_id])).each do |rec|
				varHasOther[rec["variation_id"]] = true unless isSelectedSample[rec["sample_id"]]
			end
		end
		varids = varHasOther.select{|k,v| !v}.keys
		return nil if varids.size == 0
		# "variation_calls.variation_id IN (#{varids.join(",")})"
		_variation_id_in(varids)
	end


	
private
	def _variation_id_in(varids)
		"variation_calls.variation_id IN (
			SELECT id FROM variations WHERE id IN (#{varids.join(",")}) ORDER BY id
		)"
	end
	
	def _variation_call_id_in(varcallids, notin = false)
		"variation_calls.id #{(notin)?"NOT":""} IN (
			SELECT id FROM variation_calls WHERE id IN (#{varcallids.join(",")}) ORDER BY id
		)"
	end

end