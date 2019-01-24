class AggregationSamples < Aggregation
	batch_attributes(Sample)
	batch_attributes(Tag)
	batch_attributes(VcfFile, Sample)
	batch_attributes(SpecimenProbe, Sample)
	
	register_aggregation :nickname,
												label:              'Sample (nickname)',
												colname:            'Sample',
												colindex:           0.9,
												aggregation_method: 'samples.nickname',
												type:               :attribute,
												checked:            false,
												category:           'Samples',
												requires:           {
													Sample => [:nickname]
												}
	register_aggregation :patient,
												label:              'Sample (patient)',
												colname:            'Patient',
												colindex:           0.9,
												aggregation_method: :patient,
												type:               :attribute,
												checked:            true,
												category:           'Samples',
												record_color:       {
													'Patient' => :factor
												},
												requires:           {
													Sample => [:patient, :entity_id]
												}
	register_aggregation :num_samples,
												label:              '#Samples with variant',
												colname:            '#Samples w/ variant',
												colindex:           2.3,
												prehook:            :num_samples_prep,
												aggregation_method: :num_samples,
												type:               :attribute,
												checked:            true,
												category:           'Samples',
												requires:           {
													VariationCall => [:sample_id, :variation_id]
												}
	register_aggregation :num_patients,
												label:              '#Patients with variant',
												colname:            '#Patients w/ variant',
												colindex:           2.4,
												prehook:            :num_patients_prep,
												aggregation_method: :num_patients,
												type:               :attribute,
												checked:            false,
												category:           'Samples',
												requires:           {
													Sample => [:patient],
													VariationCall => [:variation_id]
												}
	register_aggregation :num_specimens,
						 label:              '#Specimen with variant',
						 colname:            '#Specimen w/ variant',
						 colindex:           2.2,
						 prehook:            :num_specimen_prep,
						 aggregation_method: :num_specimen_probes,
						 type:               :attribute,
						 checked:            true,
						 category:           'Samples',
						 requires:           {
							 Sample => [:specimen_probe_id],
							 VariationCall => [:variation_id]
						 }
	register_aggregation :num_entities,
						 label:              '#Entity with variant',
						 colname:            '#Entity w/ variant',
						 colindex:           2.1,
						 prehook:            :num_entity_prep,
						 aggregation_method: :num_entities,
						 type:               :attribute,
						 checked:            true,
						 category:           'Samples',
						 requires:           {
							 Sample => [:entity_id],
							 VariationCall => [:variation_id]
						 }
	register_aggregation :num_entity_groups,
						 label:              '#Entity Group with variant',
						 colname:            '#Entity Group w/ variant',
						 colindex:           2.0,
						 prehook:            :num_entity_group_prep,
						 aggregation_method: :num_entity_groups,
						 type:               :attribute,
						 checked:            true,
						 category:           'Samples',
						 requires:           {
							 Sample => [:entity_group_id],
							 VariationCall => [:variation_id]
						 }
	register_aggregation :num_samples_gene,
												label:              '#Samples with gene',
												colname:            '#Samples w/ gene',
												colindex:           3,
												prehook:            :num_samples_gene_prep,
												aggregation_method: :num_samples_gene,
												type:               :attribute,
												checked:            false,
												category:           'Samples',
												requires:           {
													Vep::Ensembl => [:gene_symbol],
													VariationCall => [:sample_id]
												}

	register_aggregation :snupy_freq,
											 label:              'SNuPy Freq',
											 colname:            'SNuPy Freq',
											 colindex:           2,
											 prehook:            :get_snupy_freq,
											 aggregation_method: :add_snupy_freq,
											 type:               :attribute,
											 checked:            false,
											 category:           'Samples',
											 color: {
													 /SNuPy Freq.*/ => create_color_gradient([0, 0.5, 1], colors = ["salmon", "lightyellow", "palegreen"])
											 },
											 requires:           {
													 VariationCall => [:variation_id, :sample_id]
											 }

	def get_snupy_freq(rows, params)
		@total_counts = {}
		@varfreq = {}
		return if params["experiment"].nil?
		return if params["user"].nil?
		organismid = Experiment.find(params[:experiment]).organism_id
		usr = User.find(params["user"])
		varids = rows.map{|id, recs| recs.map{|rec| rec["variation_calls.variation_id"]}}.flatten.uniq

		smplids = usr.reviewable(Sample).joins(:organism).where("organisms.id" => organismid).pluck("samples.id")
		num_smpls = smplids.size
		num_entities = Sample.where(id: smplids).count(:entity_id, distinct: true)
		num_entgroups = Sample.where(id: smplids).count(:entity_group_id, distinct: true)
#		@total_counts = {
#				smplids: smplids,
#				num_smpls: num_smpls,
#				num_ents: num_entities,
#				num_entg: num_entgroups
#		}
		varids2smpl = VariationCall.where(variation_id: varids, sample_id: smplids).group(:variation_id).count(:sample_id, distinct: true)
		varids2ents = VariationCall.joins(:sample).where(variation_id: varids, sample_id: smplids).where("entity_id IS NOT NULL").group(:variation_id).count(:entity_id, distinct: true)
		varids2entg = VariationCall.joins(:sample).where(variation_id: varids, sample_id: smplids).where("entity_group_id IS NOT NULL").group(:variation_id).count(:entity_group_id, distinct: true)
		varids.each do |varid|
			@varfreq[varid] = {
					smpl: ((varids2smpl[varid].to_f || 0.to_f)/num_smpls.to_f).round(3),
					ents: ((varids2ents[varid].to_f || 0.to_f)/num_entities.to_f).round(3),
					entg: ((varids2entg[varid].to_f || 0.to_f)/num_entgroups.to_f).round(3)
			}
		end
	end

	def add_snupy_freq(rec)
		{
				"Sample" => @varfreq[rec["variation_calls.variation_id"]][:smpl],
				"Entity" => @varfreq[rec["variation_calls.variation_id"]][:ents],
				"EntityGroup" => @varfreq[rec["variation_calls.variation_id"]][:entg],
		}
	end

	def count_prep(arr, attr_name)
		@varid2elment = {} if @varid2elment.nil?
		@varid2elment[attr_name] = {} if @varid2elment[attr_name].nil?
		arr.each do |groupkey, recs|
			recs.each do |rec|
				@varid2elment[attr_name][rec['variation_calls.variation_id']] = [] if @varid2elment[attr_name][rec['variation_calls.variation_id']].nil?
				next if rec[attr_name].nil?
				@varid2elment[attr_name][rec['variation_calls.variation_id']] << rec[attr_name]
				@varid2elment[attr_name][rec['variation_calls.variation_id']].uniq!
			end
		end
		#@varid2elment[attr_name].keys.each do |varid|
		#	@varid2elment[attr_name][varid] = @varid2elment[attr_name][varid].length
		#end
	end
	
	def num_for(attr_name, varid, path_method = nil)
		@varid2elment = {} if @varid2elment.nil?
		@varid2elment[attr_name] = {} if @varid2elment[attr_name].nil?
		#@varid2elment[attr_name][varid].to_i
		ids = @varid2elment[attr_name][varid]
		num = ids.length.to_i
		if (num > 0) then
			if (!path_method.nil?)
				ActionController::Base.helpers.link_to("#{num}", Rails.application.routes.url_helpers.send(path_method, ids: ids))
			else
				num.to_s
			end
		else
			"0"
		end
	end
	
	def num_entity_group_prep(arr)
		count_prep(arr, 'samples.entity_group_id')
	end
	
	def num_entity_prep(arr)
		count_prep(arr, 'samples.entity_id')
	end
	
	def num_specimen_prep(arr)
		count_prep(arr, 'samples.specimen_probe_id')
	end
	
	def num_samples_prep(arr)
		count_prep(arr, 'variation_calls.sample_id')
	end
	
	def num_patients_prep(arr)
		count_prep(arr, 'samples.patient')
	end
	
	def num_entity_groups(rec)
		num_for('samples.entity_group_id', rec['variation_calls.variation_id'], :entity_groups_path)
	end
	
	def num_entities(rec)
		num_for('samples.entity_id', rec['variation_calls.variation_id'], :entities_path)
	end
	
	def num_specimen_probes(rec)
		num_for('samples.specimen_probe_id', rec['variation_calls.variation_id'], :specimen_probes_path)
	end
	
	def num_samples(rec)
		num_for('variation_calls.sample_id', rec['variation_calls.variation_id'], :samples_path)
	end
	
	def num_patients(rec)
		num_for('samples.patient', rec['variation_calls.variation_id'])
	end
	
	def num_samples_gene_prep(arr)
		@gene2numsamples = {}
		arr.each do |groupkey, recs|
			recs.each do |rec|
				@gene2numsamples[rec[Vep::Ensembl.colname('gene_symbol')]] = [] if @gene2numsamples[rec[Vep::Ensembl.colname('gene_symbol')]].nil?
				@gene2numsamples[rec[Vep::Ensembl.colname('gene_symbol')]] << rec[Vep::Ensembl.colname('gene_symbol')]
				@gene2numsamples[rec[Vep::Ensembl.colname('gene_symbol')]].uniq!
			end
		end
		@gene2numsamples.keys.each do |symbol|
			@gene2numsamples[symbol] = @gene2numsamples[symbol].length 
		end
		@gene2numsamples[nil] = nil
	end
	
	def num_samples_gene(rec)
		return nil if rec[Vep::Ensembl.colname('gene_symbol')].nil?
		"#{@gene2numsamples[rec[Vep::Ensembl.colname('gene_symbol')]]} (#{rec[Vep::Ensembl.colname('gene_symbol')]})"
	end
	
	def patient(rec)
		patname = rec['samples.patient']
		entid   = rec['samples.entity_id']
		
		if (entid.to_s != '') then
			ActionController::Base.helpers.link_to(patname, Rails.application.routes.url_helpers.entity_path(id: entid))
		else
			patname
		end
	end
end
