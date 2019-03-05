class VariantInterpretationReportTemplate < ReportTemplate
	
	def self.report_klass
		ReportEntity
	end
	
	def self.required_parameters(params)
		params.merge({
			             gene_panels: [{"id" => -1, "name" =>  "Complete Profile"}] + GenericGeneList.select([:id, :name]).map(&:attributes),
			             phenotype_keyword: " "
		             })
	end
	
	def report_klass
		self.class.report_klass
	end
	
	def default_attributes
		super.merge({
			            name: "ACMG/AMP Report #{self.klass_instance.name}",
			            identifier: "ACMG/AMP variant interpretation report",
			            type: report_klass.name,
			            xref_id: self.klass_instance.id,
			            institution_id: self.klass_instance.institution.id,
			            filename: "ACMG/AMP_report_#{self.klass_instance.name}.docx",
			            mime_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
			            description: "A report that helps investigators to interpret variants by the ACMG/AMP interpretation schema"
		            })
	end
	
	# report_info = {
	#   variation_call_ids: [],
	#   gene_panels: [],
	#   phenotype_keyword: ""
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
		rt = create_acmg_table()
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
			docx.style do
				id              'Normal'  # sets the internal identifier for the style.
				name            'normal' # sets the friendly name of the style.
				type            'paragraph' # sets the style type. accepts `paragraph` or `character`
				font            'Arial' # sets the font family.
				color           '000000'    # sets the text color. accepts hex RGB.
				size            20          # sets the font size. units in half points.
				line            240         # sets the line height. units in twips.
			end
			rt.add_to_document(docx)
		
			varids.each do |varid|
				acmg_page = create_acmg_page(varid)
				docx.page
				docx.h1 acmg_page[:header]
				acmg_page[:table].add_to_document(docx)
			end
		end
		return result if 1 == 1
		if report_params["gene_panels"].map(&:to_s).include?("-1") then
			tables["Profile"] = create_table(entity, nil)
		end
		GenericGeneList.where(id: report_params["gene_panels"]).each do |gl|
			tables[gl.name] = create_table(entity, gl.genes)
		end
		
		generate_docx("app/views/reports/templates/gene_report.docx.erb", report_params.merge({entity: entity, tables: tables}))
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
	
	def create_acmg_page(varid)
		header = ["Strong benign", "Supporting benign", "Supporting pathogenic", "Moderate pathogenic", "Strong pathogenic", "Very strong pathogenic"]
		records = {
			population_data: {
				"Strong benign" => "MAF is too high for disorder BA1/BS1 OR observation in controls inconsistent with disease penetrance BS2",
				"Moderate pathogenic" => "Absent in population databases PM2",
				"Strong pathogenic" => ps4(varid)
			},
			compulational_predictive_data: {
				"Supporting benign" => "Multiple lines of computational evidence suggest no impact on gene /gene product BP4.\nMissense in gene where only truncating cause disease BP1.\nSilent variant with non predicted splice impact BP7.\nIn-frame indels in repeat w/out known function BP3",
				"Supporting pathogenic" => "Multiple lines of computational evidence support a deleterious effect on the gene /gene product PP3",
				"Moderate pathogenic" => "Novel missense change at an amino acid residue where a different pathogenic missense change has been seen before PM5.\nProtein length changing variant PM4",
				"Strong pathogenic" => "Same amino acid change as an established pathogenic variant PS1",
				"Very strong pathogenic" => pvs1(varid)
			},
			functional_data: {
				"Strong benign" => "Well-established functional studies show no deleterious effect BS3",
				"Supporting pathogenic" => "Missense in gene with low rate of benign missense variants and path. missenses common PP2",
				"Moderate pathogenic" => "Mutational hot spot or well-studied functional domain without benign variation PM1",
				"Strong pathogenic" => ps3(varid)
			},
			segregation_data: {
				"Strong benign" => "Nonsegregation with disease BS4 Observed",
				"Supporting pathogenic" => "Cosegregation with disease in multiple affected family members PP1 (possibly increasing towards 'Very strong pathogenic')"
			},
			denovo_data: {
				"Moderate pathogenic" => "De novo (without paternity & maternity confirmed) PM6",
				"Strong pathogenic" => ps2(varid)
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
			rt.add_row(row, {size: 14})
		end
		{header: varid, table: rt}
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
	
	end
	# De novo (both maternity and paternity confirmed) in a patient with the disease and no family history
	def ps2(varid)
		{
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
		pubmeds = query_vep(varid).pluck(:pubmed).uniq.map{|pubid| ReportTableLink.new("https://www.ncbi.nlm.nih.gov/pubmed/#{pubid}", pubid)}
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
	
	end
	def pm2(varid)
	end
	def pm3(varid)
	end
	def pm4(varid)
	end
	def pm5(varid)
	end
	def pm6(varid)
	end
	
	def pp1(varid)
	end
	def pp2(varid)
	end
	def pp3(varid)
	end
	def pp4(varid)
	end
	def pp5(varid)
	end
	
	def ba1(varid)
		query_vep(varid).map{|vep| "#{vep.exac_adj_allele}(#{vep.exac_adj_maf})"}.uniq
	end
	
	def bs1(varid)
		ba1(varid)
	end
	def bs2(varid)
	end
	def bs3(varid)
	end
	def bs4(varid)
	end
	
	def bp1(varid)
	end
	def bp2(varid)
	end
	def bp3(varid)
	end
	def bp4(varid)
	end
	def bp5(varid)
	end
	def bp6(varid)
	end
	def bp7(varid)
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
