class VariantInterpretationReportTemplate < ReportTemplate
	
	def self.report_klass
		ReportEntity
	end
	
	def self.required_parameters(params)
		params.merge({
			             gene_panels: [{"id" => -1, "name" =>  "all selected variants"}] + GenericGeneList.select([:id, :name]).map(&:attributes),
			             report_name: "ACMG/AMP variant interpretation report",
			             expected_population_frequency: "0.01"
		             })
	end
	
	def report_klass
		self.class.report_klass
	end
	
	def default_attributes
		super.merge({
			            name:  report_params["report_name"],
			            identifier: "ACMG/AMP report for #{self.klass_instance.name}",
			            type: report_klass.name,
			            xref_id: self.klass_instance.id,
			            institution_id: self.klass_instance.institution.id,
			            filename: "ACMG_AMP_report_#{self.klass_instance.name}.docx",
			            mime_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
			            description: "A report that helps investigators to interpret variants by the ACMG/AMP interpretation schema"
		            })
	end
	
	# report_info = {
	#   variation_call_ids: [],
	#   gene_panels: [],
	#   phenotype_keyword: "",
	#   expected_population_frequency: 1.0
	# }
	# RETURN: A text containnig the generated report
	def report_content(entity)
		@entity = self.klass_instance
		
		
		tables = {}
		vcids = (report_params["ids"] || []).map{|x| x.split(" | ")}.flatten
		varcalls = VariationCall
			         .joins(:sample)
			         .where("samples.entity_id" => entity.id)
			         .where("variation_calls.id" => vcids)
		varids = varcalls.pluck(:variation_id).uniq
		
		if not report_params["gene_panels"].map(&:to_s).include?("-1") then
			genes = GenericGeneList.where(id: report_params["gene_panels"]).map do |gl|
				gl.genes
			end
			genes = genes.flatten.uniq.sort
			varids_symbols = query_vep(varids).where(gene_symbol: genes).pluck(:variation_id).uniq || []
			varids_transcripts = query_vep(varids).where(transcript_id: genes).pluck(:variation_id).uniq || []
			varids_genes = query_vep(varids).where(gene_id: genes).pluck(:variation_id).uniq || []
			varids = (varids_symbols + varids_transcripts + varids_genes).uniq
		end
		
		
		result = with_docx do |docx|
			docx.page_size do
				width       15840       # sets the page width. units in twips.
				height      12240       # sets the page height. units in twips.
				orientation :landscape  # sets the printer orientation. accepts :portrait and :landscape.
			end
			docx.page_margins do
				left    560     # sets the left margin. units in twips.
				right   560     # sets the right margin. units in twips.
				top     560    # sets the top margin. units in twips.
				bottom  560    # sets the bottom margin. units in twips.
			end
			
			add_styles(docx)
			create_front_page(docx)
			docx.page
			docx.h2 "ACMG/AMP Criteria overview (Richards et al. 2015)"
			create_acmg_table().add_to_document(docx)
			
			if varids.size > 0
				varids.each do |varid|
					acmg_page = create_acmg_page(varid)
					docx.page
					docx.h2 acmg_page[:header]
					acmg_page[:table].add_to_document(docx)
				end
			else
				docx.page
				docx.h2 "No variants found in selected panels"
			end
			docx.page
			docx.h2 "ACMG/AMP Code Description (Richards et al. 2015)"
			create_acmg_description_table.add_to_document(docx)
		end
		
		return result
	end
	
	def add_styles(docx)
		defaults = {
			color: "000000",
			color1: "444444",
			color_highlight: "4682B4",
			font: "Helvetica",
			font_serif: "Times",
			size: 16,
			
		}
		docx.style do
			id              'Heading1'  # sets the internal identifier for the style.
			name            'heading 1' # sets the friendly name of the style.
			type            'paragraph' # sets the style type. accepts `paragraph` or `character`
			font            defaults[:font] # sets the font family.
			color           defaults[:color_highlight]    # sets the text color. accepts hex RGB.
			size            52          # sets the font size. units in half points.
			bold            true       # sets the font weight.
			align           :center       # sets the alignment. accepts :left, :center, :right, and :both.
			line            360         # sets the line height. units in twips.
			top             100         # sets the spacing above the paragraph. units in twips.
			bottom          100           # sets the spacing below the paragraph. units in twips.
		end
		docx.style do
			id              'Heading2'  # sets the internal identifier for the style.
			name            'heading 2' # sets the friendly name of the style.
			type            'paragraph' # sets the style type. accepts `paragraph` or `character`
			font            defaults[:font] # sets the font family.
			color           defaults[:color]    # sets the text color. accepts hex RGB.
			size            32          # sets the font size. units in half points.
			bold            false       # sets the font weight.
			align           :center       # sets the alignment. accepts :left, :center, :right, and :both.
			line            360         # sets the line height. units in twips.
			top             50         # sets the spacing above the paragraph. units in twips.
			bottom          50           # sets the spacing below the paragraph. units in twips.
		end
		docx.style do
			id              'Heading3'  # sets the internal identifier for the style.
			name            'heading 3' # sets the friendly name of the style.
			type            'paragraph' # sets the style type. accepts `paragraph` or `character`
			font            defaults[:font] # sets the font family.
			color           defaults[:color1]    # sets the text color. accepts hex RGB.
			size            42          # sets the font size. units in half points.
			bold            false       # sets the font weight.
			caps            true
			align           :left       # sets the alignment. accepts :left, :center, :right, and :both.
			line            360         # sets the line height. units in twips.
			top             50         # sets the spacing above the paragraph. units in twips.
			bottom          50           # sets the spacing below the paragraph. units in twips.
		end
		docx.style do
			id              'Normal'  # sets the internal identifier for the style.
			name            'normal' # sets the friendly name of the style.
			type            'paragraph' # sets the style type. accepts `paragraph` or `character`
			font            'Arial' # sets the font family.
			color           '000000'    # sets the text color. accepts hex RGB.
			size            20          # sets the font size. units in half points.
			line            240         # sets the line height. units in twips.
		end
		#docx.style do
		#	id              'Normal'  # sets the internal identifier for the style.
		#	name            'normal' # sets the friendly name of the style.
		#	type            'paragraph' # sets the style type. accepts `paragraph` or `character`
		#	font            defaults[:font_serif] # sets the font family.
		#	color           defaults[:color]    # sets the text color. accepts hex RGB.
		#	size            defaults[:size]          # sets the font size. units in half points.
		#end
		docx.style do
			id              'notes'  # sets the internal identifier for the style.
			name            'notes' # sets the friendly name of the style.
			type            'character' # sets the style type. accepts `paragraph` or `character`
			font            defaults[:font] # sets the font family.
			color           defaults[:color]    # sets the text color. accepts hex RGB.
			size            32          # sets the font size. units in half points.
			bold            true       # sets the font weight.
			line            120         # sets the line height. units in twips.
		end
		docx
	end
	
	def create_front_page(docx)
		#user = User.find(user.id)
		docx.h1 "Genetic Analysis #{entity.name}"
		docx.h2 "#{user.full_name} | #{user.email} | #{Date.today.strftime("%d %B %Y")}"
		docx.hr
		context = self
		docx.p do
			text "Name: " + context.entity.name, style: "notes"
			br
			text "Parents: " + context.entity.parents.map(&:name).join(" & "), style: "notes"
			br
			text "Siblings: " + context.entity.siblings.map(&:name).join(" & "), style: "notes"
			br
			context.entity.tags.group_by(&:category).each do |category, tags|
				text "#{category}: #{tags.map{|t| t.value}.join(",")}", style: "notes"
				br
			end
		end
		docx
	end
	
	def create_acmg_description_table()
		header = ["ACMG/AMP Code", "Description"]
		records = {
				   "Pathogenic": "",
				   "Very Strong": "",
				   PVS1: "null variant (nonsense, frameshift, canonical ±1 or 2 splice sites, initiation codon, single or multiexon deletion) in a gene where LOF is a known mechanism of disease",
				   "Strong": "",
		           PS1: "Same amino acid change as a previously established pathogenic variant regardless of nucleotide change",
		           PS2: "De novo (both maternity and paternity confirmed) in a patient with the disease and no family history",
		           PS3: "Well-established in vitro or in vivo functional studies supportive of a damaging effect on the gene or gene product",
		           PS4: "The prevalence of the variant in affected individuals is significantly increased compared with the prevalence in controls",
				   "Moderate": "",
		           PM1: "Located in a mutational hot spot and/or critical and well-established functional domain (e.g., active site of an enzyme) without benign variation",
		           PM2: "Absent from controls (or at extremely low frequency if recessive) (table 6) in Exome Sequencing Project, 1000 Genomes Project, or Exome Aggregation Consortium",
		           PM3: "For recessive disorders, detected in trans with a pathogenic variant",
		           PM4: "Protein length changes as a result of in-frame deletions/insertions in a nonrepeat region or stop-loss variants",
		           PM5: "Novel missense change at an amino acid residue where a different missense change determined to be pathogenic has been seen before",
		           PM6: "Assumed de novo, but without confirmation of paternity and maternity",
				   "Supporting": "",
				   PP1: "Cosegregation with disease in multiple affected family members in a gene definitively known to cause the disease",
		           PP2: "Missense variant in a gene that has a low rate of benign missense variation and in which missense variants are a common mechanism of disease",
		           PP3: "Multiple lines of computational evidence support a deleterious effect on the gene or gene product (conservation, evolutionary, splicing impact, etc.)",
		           PP4: "Patient’s phenotype or family history is highly specific for a disease with a single genetic etiology",
		           PP5: "Reputable source recently reports variant as pathogenic, but the evidence is not available to the laboratory to perform an independent evaluation",
				   "Benign": "",
				   "Stand-alone ": "",
				   BA1: "Allele frequency is >5% in Exome Sequencing Project, 1000 Genomes Project, or Exome Aggregation Consortium",
				   "Strong ": "",
				   BS1: "Allele frequency is greater than expected for disorder (see table 6)",
		           BS2: "Observed in a healthy adult individual for a recessive (homozygous), dominant (heterozygous), or X-linked (hemizygous) disorder, with full penetrance expected at an early age",
		           BS3: "Well-established in vitro or in vivo functional studies show no damaging effect on protein function or splicing",
		           BS4: "Lack of segregation in affected members of a family",
				   "Supporting ": "",
				   BP1: "Missense variant in a gene for which primarily truncating variants are known to cause disease",
		           BP2: "Observed in trans with a pathogenic variant for a fully penetrant dominant gene/disorder or observed in cis with a pathogenic variant in any inheritance pattern",
		           BP3: "In-frame deletions/insertions in a repetitive region without a known function",
		           BP4: "Multiple lines of computational evidence suggest no impact on gene or gene product (conservation, evolutionary, splicing impact, etc.)",
		           BP5: "Variant found in a case with an alternate molecular basis for disease",
		           BP6: "Reputable source recently reports variant as benign, but the evidence is not available to the laboratory to perform an independent evaluation",
		           BP7: "A synonymous (silent) variant for which splicing prediction algorithms predict no impact to the splice consensus sequence nor the creation of a new splice site AND the nucleotide is not highly conserved"
		}
		rt = ReportTable.new(header)
		records.each do |code, description|
			row = [code, description]
			rt.add_row(row, {size: 18})
		end
		rt
	end
	
	def create_acmg_table()
		header = ["Strong benign", "Supporting benign", "Supporting pathogenic", "Moderate pathogenic", "Strong pathogenic", "Very strong pathogenic"]
		records = {
			population_data: {
				"Strong benign" => "MAF is too high for disorder BA1/BS1 OR observation in controls inconsistent with disease penetrance BS2",
				"Moderate pathogenic" => "Absent in population databases PM2",
				"Strong pathogenic" => "Prevalence in affected statistically increased over controls PS4"
			},
			compulational_predictive_data: {
				"Supporting benign" => "Multiple lines of computational evidence suggest no impact on gene /gene product BP4.\nMissense in gene where only truncating cause disease BP1.\nSilent variant with non predicted splice impact BP7.\nIn-frame indels in repeat w/out known function BP3",
				"Supporting pathogenic" => "Multiple lines of computational evidence support a deleterious effect on the gene /gene product PP3",
				"Moderate pathogenic" => "Novel missense change at an amino acid residue where a different pathogenic missense change has been seen before PM5.\nProtein length changing variant PM4",
				"Strong pathogenic" => "Same amino acid change as an established pathogenic variant PS1",
				"Very strong pathogenic" => "Predicted null variant in a gene where LOF is a known mechanism of disease PVS1"
			},
			functional_data: {
				"Strong benign" => "Well-established functional studies show no deleterious effect BS3",
				"Supporting pathogenic" => "Missense in gene with low rate of benign missense variants and path. missenses common PP2",
				"Moderate pathogenic" => "Mutational hot spot or well-studied functional domain without benign variation PM1",
				"Strong pathogenic" => "Well-established functional studies show a deleterious effect PS3"
			},
			segregation_data: {
				"Strong benign" => "Nonsegregation with disease BS4 Observed",
				"Supporting pathogenic" => "Cosegregation with disease in multiple affected family members PP1 (possibly increasing towards 'Very strong pathogenic')"
			},
			denovo_data: {
				"Moderate pathogenic" => "De novo (without paternity & maternity confirmed) PM6",
				"Strong pathogenic" => "De novo (paternity and maternity confirmed) PS2"
			},
			allelic_data: {
				"Supporting benign" => "Observed in trans with a dominant variant BP2.\nObserved in cis with a pathogenic variant BP2",
				"Moderate pathogenic" => "For recessive disorders, detected in trans with a pathogenic variant PM3"
			},
			other_database: {
				"Supporting benign" => "Reputable source without shared data = benign BP6",
				"Supporting pathogenic" => "Reputable source = pathogenic PP5"
			},
			other_data: {
				"Supporting benign" => "Found in case with an alternate cause BP5",
				"Supporting pathogenic" => "Patient’s phenotype or FH highly specific for gene PP4"
			}
		}
		rt = ReportTable.new(%w(Category|Evidence)+header)
		records.each do |category, columns|
			row = columns.dup
			row["Category|Evidence"] = category.to_s.humanize
			rt.add_row(row, {size: 16})
		end
		rt
	end
	
	def call_criteria(varid, *args)
		args.map{|arg|
			"#{arg.to_s.upcase}: #{self.send(arg, varid)}"
		}.join("\n")
	end
	
	def create_acmg_page(varid)
		expected_pop_frequency = (report_params["expected_population_frequency"] || 1.0).to_f
		header = ["Strong benign", "Supporting benign", "Supporting pathogenic", "Moderate pathogenic", "Strong pathogenic", "Very strong pathogenic"]
		records = {
			population_data: {
				"Strong benign" => "BA1: #{ba1(varid)},\nBS1: #{bs1(varid, expected_pop_frequency)},\nBS2: #{bs2(varid)}",
				"Moderate pathogenic" => call_criteria(varid, :pm2),
				"Strong pathogenic" => call_criteria(varid, :ps4)
			},
			compulational_predictive_data: {
				"Supporting benign" =>  call_criteria(varid, :bp4, :bp1, :bp7, :bp3),
				"Supporting pathogenic" => call_criteria(varid, :pp3),
				"Moderate pathogenic" =>  call_criteria(varid, :pm4, :pm5),
				"Strong pathogenic" => call_criteria(varid, :ps1),
				"Very strong pathogenic" => pvs1(varid)
			},
			functional_data: {
				"Strong benign" => call_criteria(varid, :bs3),
				"Supporting pathogenic" => call_criteria(varid, :pp2),
				"Moderate pathogenic" => call_criteria(varid, :pm1),
				"Strong pathogenic" => call_criteria(varid, :ps3),
			},
			segregation_data: {
				"Strong benign" => call_criteria(varid, :bs4),
				"Supporting pathogenic" => call_criteria(varid, :pp1)
			},
			denovo_data: {
				"Moderate pathogenic" => call_criteria(varid, :pm6),
				"Strong pathogenic" => call_criteria(varid, :ps2),
			},
			allelic_data: {
				"Supporting benign" => call_criteria(varid, :bp2),
				"Moderate pathogenic" => call_criteria(varid, :pm3)
			},
			other_database: {
				"Supporting benign" => call_criteria(varid, :bp6),
				"Supporting pathogenic" => call_criteria(varid, :pp5)
			},
			other_data: {
				"Supporting benign" => call_criteria(varid, :bp5),
				"Supporting pathogenic" => call_criteria(varid, :pp4)
			}
		}
		rt = ReportTable.new(%w(Category|Evidence)+header)
		records.each do |category, columns|
			row = columns.dup
			row["Category|Evidence"] = category.to_s.humanize
			rt.add_row(row, {size: 14})
		end
		tbl_header = query_vep(varid).select([:gene_symbol, :transcript_id, :hgvsc]).uniq
			             .reject{|vep| vep.hgvsc.nil?}
			             .map{|vep| "#{vep.gene_symbol}(#{vep.transcript_id}.#{vep.hgvsc})"}
						 .join(" | ")
		if tbl_header == "" then
			tbl_header = query_vep(varid).select([:gene_symbol]).uniq.join(" | ")
		end
		{header: tbl_header, table: rt}
	end
	
	def query_vep(varid)
		Vep::Ensembl
			.where(organism_id: organism.id, variation_id: varid)
			.where(canonical: 1)
	end
	def query_annovar(varid)
		Annovar
			.where(organism_id: organism.id, variation_id: varid)
	end
	
	def organism
		@organism ||= entity.organism
	end
	
	def entity
		self.klass_instance
	end
	
	def user
		@user ||= User.find(report_params[:user_id])
	end
	
	#PVS1 null variant (nonsense, frameshift, canonical ±1 or 2 splice sites, initiation codon, single or multiexon deletion) in a gene where LOF is a known mechanism of disease
	def pvs1(varid)
		query_vep(varid).where(
			consequence: %w(missense_variant splice_acceptor_variant splice_donor_variant start_lost stop_gained stop_lost frameshift_variant protein_altering_variant)
		).select([:gene_symbol, :consequence]).map{|vep| "#{vep.gene_symbol}(#{vep.consequence})"}.join("\n")
	end
	
	#Same amino acid change as a previously established pathogenic variant regardless of nucleotide change
	def ps1(varid)
		has_clinvar = Clinvar.where(variation_id: varid)
			              .where("organism_id" => organism.id)
			              .where("is_pathogenic" => true)
			              .reject{|cv| cv.clndn.nil?}.size > 0
		if has_clinvar then
			is_missense = query_vep(varid).where(
				consequence: %w(missense_variant)
			).count > 0
			if is_missense then
				"Is pathogenic AND missense."
			else
				"Is pathogenic, but not missense"
			end
		else
			"Not a pathogenic variant"
		end
	end
	# De novo (both maternity and paternity confirmed) in a patient with the disease and no family history
	def ps2(varid)
		@ps2 = {
			patient: entity.baf(varid),
			father: entity.father.first.baf(varid),
			mother: entity.father.first.baf(varid),
			siblings: entity.siblings.map{|s|s.baf(varid)}.flatten,
		}.map{|name, bafs|
			"#{name.upcase}: #{bafs.map{|specimen_probe, baf| "#{specimen_probe.name} (#{baf})"}.join(", ")}"
		}.join("\n")
	end
	# Well-established in vitro or in vivo functional studies supportive of a damaging effect on the gene or gene product
	def ps3(varid)
		#pubmeds = query_vep(varid).pluck(:pubmed).uniq.map{|pubid| ReportTableLink.new("https://www.ncbi.nlm.nih.gov/pubmed/#{pubid}", pubid)}
		pubmeds = query_vep(varid).pluck(:pubmed).uniq.map{|pubid| "https://www.ncbi.nlm.nih.gov/pubmed/#{pubid}"}.join("\n")
	end
	#The prevalence of the variant in affected individuals is significantly increased compared with the prevalence in controls
	def ps4(varid)
		smplids = user.reviewable(Sample).joins(:organism).where("organisms.id" => organism.id).pluck("samples.id")
		entids = Sample.where(id: smplids).select(:entity_id).pluck(:entity_id).uniq.reject(&:nil?)
		controls = Entity.joins(:tags).where("entities.id" => entids, "tags.value" => "shared control").pluck("entities.id")
		cases = Entity.joins(:tags).where("entities.id" => entids, "tags.value" => entity.tags.where(category: "CLASS").first.value).pluck("entities.id")
		varcount_case = VariationCall.joins(:sample).where(variation_id: varid, "samples.entity_id" => cases).where("entity_id IS NOT NULL").count(:entity_id, distinct: true)
		varcount_control = VariationCall.joins(:sample).where(variation_id: varid, "samples.entity_id" => cases).where("entity_id IS NOT NULL").count(:entity_id, distinct: true)
		"Case: #{varcount_case}, Control: #{varcount_control}, Total: #{entids.size}"
	end
	
	#Located in a mutational hot spot and/or critical and well-established functional domain (e.g., active site of an enzyme) without benign variation
	def pm1(varid)
		Clinvar.where(variation_id: varid).where("organism_id" => organism.id)
			.reject{|cv| cv.clndn.nil?}
			.map{|cv|
				"[#{cv.symbol}] #{cv.clndn} (distance: #{cv.distance})"
			}.uniq.join("\n")
	end
	#PM2 Absent from controls (or at extremely low frequency if recessive) (table 6) in Exome Sequencing Project, 1000 Genomes Project, or Exome Aggregation Consortium
	def pm2(varid)
		ba1(varid)
	end
	# PM3 For recessive disorders, detected in trans with a pathogenic variant
	def pm3(varid)
		"NA"
	end
	# PM4 Protein length changes as a result of in-frame deletions/insertions in a nonrepeat region or stop-loss variants
	def pm4(varid)
		query_vep(varid).where(
			consequence: %w(stop_gained stop_lost frameshift_variant inframe_insertion inframe_delection)
		).select([:gene_symbol, :consequence]).map{|vep| "#{vep.gene_symbol}(#{vep.consequence})"}.join("\n")
	end
	# PM5 Novel missense change at an amino acid residue where a different missense change determined to be pathogenic has been seen before
	def pm5(varid)
		has_clinvar = Clinvar.where(variation_id: varid)
			              .where("organism_id" => organism.id)
			              .where("is_pathogenic" => true)
			              .reject{|cv| cv.clndn.nil?}.size > 0
		if has_clinvar then
			is_missense = query_vep(varid).where(
				consequence: %w(missense_variant)
			).count > 0
			if is_missense then
				"Is pathogenic AND missense. Check for novelty."
			else
				"Is pathogenic, but not missense"
			end
		else
			"Not a pathogenic variant"
		end
	end
	#PM6 Assumed de novo, but without confirmation of paternity and maternity
	def pm6(varid)
		# we will assume de novo if no dbsnp exists
		has_dbsnp = query_vep(varid).where(
			dbsnp: nil
		).count > 0
		if has_dbsnp then
			"Reported in dbSNP - not assumed de novo"
		else
			"Missing in dbSNP - assumed DE NOVO"
		end
	end
	# PP1 Cosegregation with disease in multiple affected family members in a gene definitively known to cause the disease
	def pp1(varid)
		ps2(varid)
	end
	# PP2 Missense variant in a gene that has a low rate of benign missense variation and in which missense variants are a common mechanism of disease
	def pp2(varid)
		is_missense = query_vep(varid).where(
			consequence: %w(missense_variant)
		).count > 0
		if is_missense then
			"is missense"
		else
			"not missense"
		end
	end
	#PP3 Multiple lines of computational evidence support a deleterious effect on the gene or gene product (conservation, evolutionary, splicing impact, etc.)
	def pp3(varid)
		# we will use exac, polyphen, sift and gerp_rs
		av = Annovar.where(variation_id: varid, organism_id: organism.id)
			     .select([:cadd_phred, :polyphen2_hdvi_pred, :polyphen2_hvar_pred, :sift_pred, :gerp_rs]).uniq
		@pp3 = {
			polyphen2_hdvi_pred: av.map{|x| x.polyphen2_hdvi_pred }.uniq.join(","),
			polyphen2_hvar_pred: av.map{|x| x.polyphen2_hvar_pred }.uniq.join(","),
			sift_pred: av.map{|x| x.sift_pred }.uniq.join(","),
			"GERP_rs > 2?" => av.map{|x| x.gerp_rs }.uniq.join(","),
			"CADD > 15?" => av.map{|x| (x.cadd_phred || 0) > 15 }.uniq.join(",")
		}.map{|name, preds|
			"#{name.upcase}: #{preds}"
		}.join("\n")
	end
	# PP4 Patient’s phenotype or family history is highly specific for a disease with a single genetic etiology
	def pp4(varid)
		entity.tags.where("tags.category": "DISEASE").pluck("tags.value")
	end
	# PP5 Reputable source recently reports variant as pathogenic, but the evidence is not available to the laboratory to perform an independent evaluation
	def pp5(varid)
		"Please consider PMID: 29543229"
	end
	
	# BA1 Allele frequency is >5% in Exome Sequencing Project, 1000 Genomes Project, or Exome Aggregation Consortium
	def ba1(varid)
		@ba1 = "EXaC: " + query_vep(varid).map{|vep| "#{vep.exac_adj_allele}(#{vep.exac_adj_maf})"}.uniq.to_s
	end
	#BS1 Allele frequency is greater than expected for disorder (see table 6)
	def bs1(varid, expected_pop_frequency)
		if query_vep(varid).select([:exac_adj_maf]).map{|vep| vep.exac_adj_maf || 0}.uniq.all?{|x| x < expected_pop_frequency} then
			"less frequent than expected"
		else
			"more frequent than expected"
		end
	end
	#BS2 Observed in a healthy adult individual for a recessive (homozygous), dominant (heterozygous), or X-linked (hemizygous) disorder, with full penetrance expected at an early age
	def bs2(varid)
		ps2(varid)
	end
	# BS3 Well-established in vitro or in vivo functional studies show no damaging effect on protein function or splicing
	def bs3(varid)
		query_vep(varid).select([:gene_symbol]).uniq.map{|vep| vep.gene_symbol}.map{|symbol|
			"https://www.genecards.org/cgi-bin/carddisp.pl?gene=#{symbol}#function"
		}.uniq.join("\n")
	end
	# BS4 Lack of segregation in affected members of a family
	def bs4(varid)
		pp1(varid)
	end
	
	# BP1 Missense variant in a gene for which primarily truncating variants are known to cause disease
	def bp1(varid)
		pp2(varid)
	end
	# BP2 Observed in trans with a pathogenic variant for a fully penetrant dominant gene/disorder or observed in cis with a pathogenic variant in any inheritance pattern
	def bp2(varid)
		"NA"
	end
	# BP3 In-frame deletions/insertions in a repetitive region without a known function
	def bp3(varid)
		"NA"
	end
	# BP4 Multiple lines of computational evidence suggest no impact on gene or gene product (conservation, evolutionary, splicing impact, etc.)
	def bp4(varid)
		pp3(varid)
	end
	# BP5 Variant found in a case with an alternate molecular basis for disease
	def bp5(varid)
		# we count how many cases have the same or different disease
		mydisease = entity.tags.where("tags.category": "DISEASE").pluck("tags.value")
		smplids = user.reviewable(Sample).joins(:organism).where("organisms.id" => organism.id).pluck("samples.id")
		entids = Sample.where(id: smplids).select(:entity_id).pluck(:entity_id).uniq.reject(&:nil?)
		cases = Entity.joins(:tags).where("entities.id" => entids, "tags.value" => entity.tags.where(category: "CLASS").first.value).pluck("entities.id")
		case_with_disease = Entity.joins(:tags).where("entities.id" => cases, "tags.category" => "DISEASE").where("tags.value" => mydisease)
		case_without_disease = Entity.joins(:tags).where("entities.id" => cases, "tags.category" => "DISEASE").where("tags.value NOT IN (#{mydisease.map{|x| "'#{x}'"}.join(",")})")
		
		varcount_with_disease = VariationCall.joins(:sample).where(variation_id: varid, "samples.entity_id" => case_with_disease).where("entity_id IS NOT NULL").count(:entity_id, distinct: true)
		varcount_without_disease = VariationCall.joins(:sample).where(variation_id: varid, "samples.entity_id" => case_without_disease).where("entity_id IS NOT NULL").count(:entity_id, distinct: true)
		"Case with disease: #{varcount_with_disease}, Cases w/o disease: #{varcount_without_disease}, Total Entities: #{entids.size}"
	end
	# BP6 Reputable source recently reports variant as benign, but the evidence is not available to the laboratory to perform an independent evaluation
	def bp6(varid)
		pp5(varid)
	end
	# BP7 A synonymous (silent) variant for which splicing prediction algorithms predict no impact to the splice consensus sequence nor the creation of a new splice site AND the nucleotide is not highly conserved
	def bp7(varid)
		"NA"
	end
	
	def create_table(entity, genes = nil)
		records = {
			transcripts: [],
			inheritance: [],
			phenotypes: []
		}
		vcids = report_params["ids"].map{|x| x.split(" | ")}.flatten
		# collect variants from variation calls
		adom = entity.autosomal_dominant(vcids)
		arec = entity.autosomal_recessive(vcids)
		comphet = entity.compound_heterozygous(vcids, Vep::Ensembl.where(canonical: 1), :transcript_id)
		denovo = entity.denovo(vcids)
		VariationCall
			.joins(:sample)
			.where("samples.entity_id" => entity.id)
			.where("variation_calls.id" => vcids)
			.group_by(&:variation_id).each do |varid, varcalls|
			var = Variation.find(varid)
			
			veps = Vep::Ensembl.where(variation_id: varid, organism_id: entity.organism.id, canonical: true)
			
			if genes then
				# next unless its in the gene list
				if not veps.any?{|vep| genes.include?(vep.gene_symbol) || genes.include?(vep.gene_id)}
					next
				end
			end
			
			family_baf = {
				Variant: var.coordinates
			}
			entity.specimen_probes.each do |spec|
				family_baf["#{entity.name} (#{spec.name})"] =  get_baf_in_specimen(varid, spec).round(2)
			end
			family_baf = family_baf.merge({
				                              Father: get_baf_in_entity(varid, entity.father).round(2),
				                              Mother: get_baf_in_entity(varid, entity.mother).round(2),
				                              Siblings: get_baf_in_entity(varid, entity.siblings).round(2),
				                              autosomal_dominant: adom[varid],
				                              autosomal_recessive: arec[varid],
				                              compound_heterozygous: comphet[varid],
				                              denovo: denovo[varid]
			                              })
			
			transcripts = {
				Variant: var.coordinates,
				Symbol: veps.map{|vep| "#{vep.gene_symbol}(#{vep.consequence})"}.join(",\n"),
				Transcript: veps.map{|vep| "#{vep.transcript_id}#{(vep.hgvsc.nil?)?"":".#{vep.hgvsc}"}"}.uniq.join(",\n"),
				#HGVSC: veps.map(&:hgvsc).join(","),
				Exac: veps.reject{|vep|vep.exac_adj_allele.to_s == ""}.map{|vep| "#{vep.exac_adj_maf} (#{vep.exac_adj_allele})"}.uniq.join(","),
				dbsnp: veps.map(&:dbsnp).uniq.join(",")
			}
			
			phenotypes = {
				Variant: var.coordinates,
				CADD: Cadd.where(variation_id: varid, organism_id: entity.organism.id).first.phred,
				OMIM: veps.map(&:gene_symbol).map{|sym| OmimGenemap.where("symbol = '#{sym}' OR symbol_alias = '#{sym}'").map{|omim| "#{omim.symbol}: #{omim.phenotype}"}}.flatten.uniq.join(",\n"),
				Clinvar: Clinvar.where(variation_id: varid, organism_id: entity.organism.id)
					         .map{|c|
						         (c.distance!=0)?"":"#{c.symbol}: #{c.clndn}"
					         }.flatten.uniq.join(",")
			}
			records[:transcripts] << transcripts
			records[:inheritance] << family_baf
			records[:phenotypes] << phenotypes
		end
		records
	end
	
	def get_baf_in_specimen(variation, specimen)
		varcalls = VariationCall.joins(:sample).where("samples.specimen_probe_id" => specimen).where("variation_id" => variation)
		varcalls.map(&:baf).to_scale.mean
	end
	
	
	def get_baf_in_entity(variation, entity)
		varcalls = VariationCall.joins(:sample).where("samples.entity_id" => entity).where("variation_id" => variation)
		varcalls.map(&:baf).to_scale.mean
	end
	
	report_klass.register_template(self)
end
