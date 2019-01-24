class AggregationVariationCall < Aggregation
	
	batch_attributes(VariationCall)
	batch_attributes(Variation)
	
	register_aggregation :variation,
						 label:              'variation',
						 colname:            'variation',
						 prehook:            :coordinates_get_format_templates,
						 aggregation_method: :coordinates,
						 type:               :batch,
						 category:           'Variation',
						 requires:           {
							 Variation => {
								 Region     => [:name, :start, :stop],
								 Alteration => [:ref, :alt]
							 }
						 }
	
	register_aggregation :coordinates,
						 label:              'Coordinates',
						 colname:            'Coordinates',
						 colindex:           0.0,
						 prehook:            :coordinates_get_format_templates,
	                     aggregation_method: :coordinates,
						 type:               :attribute,
						 checked:            true,
						 category:           'Variation',
						 requires:           {
							 Variation => {
								 Region     => [:name, :start, :stop],
								 Alteration => [:ref, :alt]
							 }
						 }
	register_aggregation :genotype,
						 label:              'Genotype',
						 colname:            'Genotype',
						 colindex:           0.1,
						 aggregation_method: :genotype,
						 type:               :attribute,
						 checked:            true,
						 category:           'Variation',
						 record_color:       {'Genotype' => {
							 /.*1[\/|]1.*/ => 'salmon',
							 /.*0[\/|]1.*/ => '#ffff99'
						 }},
						 requires:           {
							 VariationCall => [:gt, :sample_id],
							 Sample        => [:nickname]
						 }
	register_aggregation :read_depth,
						 label:              'Read depth',
						 colname:            'Read depth',
						 colindex:           0.12,
						 aggregation_method: :read_depth,
						 type:               :attribute,
						 checked:            true,
						 category:           'Variation',
						 requires:           {
							 VariationCall => [:dp],
							 Sample        => [:nickname]
						 }
	register_aggregation :ballele_frequency,
						 label:              'B-Allele Frequency',
						 colname:            'BAF',
						 colindex:           0.13,
						 aggregation_method: :baf,
						 type:               :attribute,
						 checked:            true,
						 category:           'Variation',
						 record_color:       Aqua.create_color_gradient([0,0.5, 1], colors = ['palegreen', 'lightyellow', 'salmon']),
						 requires:           {
							 VariationCall => [:ref_reads, :alt_reads],
							 Sample        => [:nickname]
						 }
	register_aggregation :cn,
						 label:              'Copy Number',
						 colname:            'Copy Number',
						 colindex:           0.4,
						 aggregation_method: lambda {|rec| "#{rec['samples.nickname']}: #{rec['variation_calls.cn']}"},
						 type:               :attribute,
						 checked:            false,
						 category:           'Variation',
						 record_color:       {
							 'Copy Number' => {
								 /.*: 0.[0-9]$/ => 'salmon',
								 /.*: 1.[0-9]$/ => 'lightsalmon',
								 /.*: 2.[0-9]$/ => '#ffff99',
								 /.*: 3.[0-9]$/ => '#ccff99',
								 /.*: [0-9.]+$/ => 'palegreen'
							 }},
						 requires:           {
							 VariationCall => [:cn],
							 Sample        => [:nickname]
						 }
	register_aggregation :fs,
						 label:              'Strand bias',
						 colname:            'Strand bias',
						 colindex:           1.41,
						 aggregation_method: lambda {|rec| "#{rec['variation_calls.fs']} (#{rec['samples.nickname']})"},
						 type:               :attribute,
						 checked:            true,
						 category:           'Variation',
						 record_color:       {
							 'Strand bias' => create_color_gradient([0, 5, 100], colors = ['palegreen', 'lightyellow', 'salmon'])},
						 requires:           {
							 VariationCall => [:fs],
							 Sample        => [:nickname]
						 }
	
	def coordinates_get_format_templates(recs, params)
		@coordinate_template = {
			'UCSC'    => 'http://genome.ucsc.edu/cgi-bin/hgTracks?clade=mammal&org=Human&db=hg19&position=chr%s:%d-%d',
			'Ensembl' => "http://#{VepAnnotation.config('ensmirror')}/Homo_sapiens/Location/View?r=%s:%d-%d"
		}
		if params[:organism_id] == Organism.human.id then
			@coordinate_template = {
				'UCSC'    => 'http://genome.ucsc.edu/cgi-bin/hgTracks?clade=mammal&org=Human&db=hg19&position=chr%s:%d-%d',
				'Ensembl' => "http://#{VepAnnotation.config('ensmirror')}/Homo_sapiens/Location/View?r=%s:%d-%d"
			}
		elsif params[:organism_id] == Organism.mouse.id then
			@coordinate_template = {
				'UCSC'    => 'http://genome.ucsc.edu/cgi-bin/hgTracks?clade=mammal&org=Mouse&db=mm10&position=chr%s:%d-%d',
				'Ensembl' => "http://#{VepAnnotation.config('ensmirror')}/Mus_musculus/Location/View?r=%s:%d-%d",
				'Mouse Genome Project' => 'https://www.sanger.ac.uk/sanger/Mouse_SnpViewer/rel-1505?gene=&context=0&loc=%s:%d-%d&release=rel-1505'
			}
		end
	end
	
	def coordinates(rec)
		linkout(
			label: sprintf('%s:%d-%d%s>%s', rec['regions.name'], rec['regions.start'], rec['regions.stop'], rec['alterations.ref'], ERB::Util.html_escape(rec['alterations.alt'])),
			url: Hash[@coordinate_template.map{|k,template| [k, sprintf(template, rec['regions.name'], rec['regions.start'], rec['regions.stop'])]}]
			#url:   {
			#	'UCSC'    => sprintf(@coordinate_template["UCSC"], rec['regions.name'], rec['regions.start'], rec['regions.stop']),
			#	'Ensembl' => sprintf(@coordinate_template["Ensembl"], rec['regions.name'], rec['regions.start'], rec['regions.stop'])
			#}
		)
		#linkout(
		#	label: sprintf("%s:%d-%d%s>%s",rec["regions.name"], rec["regions.start"], rec["regions.stop"], rec["alterations.ref"], ERB::Util.html_escape(rec["alterations.alt"])),
		#	url:   sprintf("http://genome.ucsc.edu/cgi-bin/hgTracks?clade=mammal&org=Human&db=hg19&position=chr%s:%d-%d",rec["regions.name"], rec["regions.start"], rec["regions.stop"])
		#)
	end
	
	def read_depth(rec)
		"#{rec['variation_calls.dp']} (#{rec['samples.nickname']})"
	end
	
	def baf(rec)
		if ((rec['variation_calls.alt_reads']+rec['variation_calls.ref_reads']) > 0) then
			"#{(rec['variation_calls.alt_reads'].to_f/(rec['variation_calls.alt_reads']+rec['variation_calls.ref_reads'])).round(3)} (#{rec['samples.nickname']})"
		else
			"NA (#{rec['samples.nickname']})"
		end
	end
	
	def genotype(rec)
		# "#{rec["variation_calls.gt"]} (#{ActionController::Base.helpers.link_to(rec["samples.nickname"], Rails.application.routes.url_helpers.samples_path(ids: [rec["variation_calls.sample_id"]]))})"
		ActionController::Base.helpers.link_to("#{rec['variation_calls.gt']} (#{rec['samples.nickname']})", Rails.application.routes.url_helpers.samples_path(ids: [rec['variation_calls.sample_id']]))
	end

end