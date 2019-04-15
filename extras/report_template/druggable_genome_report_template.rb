class DruggableGenomeReportTemplate < ReportTemplate
	
	def self.report_klass
		ReportEntity
	end
	
	def self.required_parameters(params)
		params.merge({
			             report_name: "Drug target report"
		             })
	end
	
	def report_klass
		self.class.report_klass
	end
	
	def default_attributes
		super.merge({
			            name:  report_params["report_name"],
			            identifier: "Drug target report for #{self.klass_instance.name}",
			            type: report_klass.name,
			            xref_id: self.klass_instance.id,
			            institution_id: self.klass_instance.institution.id,
			            filename: "drug_target_report_#{self.klass_instance.name}.docx",
			            mime_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
			            description: "Report for targetable mutations. "
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
		
		# download data from
		pnl = GenericGeneList.where(name: "DGIDB-drug-gene-interactions", description: "DGIDB interactions.").first
		if pnl.nil? then
			pnl = GenericGeneList.create({
				                             name: "DGIDB-drug-gene-interactions",
				                             title: "Drug Gene Interaction Database",
				                             description: "DGIDB interactions."
			                             })
		end
		if pnl.genes.size == 0 then
			remoteurl = "http://www.dgidb.org/data/interactions.tsv"
			localfile = File.join(Rails.root, "tmp", "dgidb_interactions.tsv")
			if !File.exists?(localfile)
				puts sprintf("Downloading %s -> %s", remoteurl, localfile)
				bytes = IO.copy_stream(open(remoteurl), localfile)
				puts sprintf("DONE %d bytes\n", bytes)
			end
			
			records = {}
			File.open(localfile, "r") do |fin|
				header = nil
				fin.each_line do |line|
					cols = line.split("\t")
					cols[-1].gsub!("\n","")
					if header.nil?
						header = cols
						next
					end
					record = Hash[header.each_with_index.map{|c,i| [header[i], cols[i].to_s.gsub("\n", " ").force_encoding("utf-8")]}]
					gene = record["gene_name"]
					source = record["interaction_claim_source"]
					interaction = record["interaction_types"]
					drug = record["drug_claim_primary_name"]
					
					gene = record["gene_claim_name"] if gene.to_s == ""
					source = "NA" if source.to_s == ""
					interaction = "NA" if interaction.to_s == ""
					next if gene.to_s == ""
					if records[gene].nil? then
						records[gene] = {
							drugs: [],
							sources: []
						}
					end
					records[gene][:drugs] << "#{drug}(#{interaction})"
					records[gene][:sources] << "#{source}"
				end
			end
			data = [%w(geneID drug(interaction) sources).join("\t")]
			data += records.map{|gene, records|
				[gene, records[:drugs].sort.uniq.join(";"), records[:sources].sort.uniq.join(";")].join("\t").gsub('"', '')
			}
			puts "Adding #{data.size} drug/gene interactions"
			
			pnl.read_data({
				data: data.join("\n"),
				file: nil,
				idx: "0",
				sep: "\t",
				header: true})
			if pnl.errors.size > 0 then
				logger.error "Cannot load DGIDB: " + pnl.errors.full_messages.to_s
				raise "Cannot load DGIDB"
			end
			pnl.save
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
			docx.h2 "Data is based on Drug Gene Interaction Database (https://doi.org/10.1093/nar/gkx1143)"
			
			
			if varids.size > 0
				drug_table = create_drug_target_table(varids)
				drug_table.add_to_document(docx)
			else
				docx.page
				docx.h2 "No variants found in selected panels"
			end
			
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
	
	def create_drug_target_table(varids)
		gene2drug = {}
		pnl = GenericGeneList.where(name: "DGIDB-drug-gene-interactions", description: "DGIDB interactions.").first
		pnl.items.each do |itm|
			x = itm.value
			gene2drug[x["gene"]] = x.delete("gene")
		end
		
		# row for each variant
		#    Query HGVS, Gene Name, CADD Score and BAF
		#    Add drug interaction info
		
		header = %w(Variant HGVS Gene CADD AlleleFreq DGIDB-drugs DGIDB-sources)
		rt = ReportTable.new(header)
		records.each do |code, description|
			drugs = gene2drug[hgnc.upcase]["drugs(interaction)"]
			sources = gene2drug[hgnc.upcase]["sources"]
			row = [coords, hgvs, hgnc, cadd, bafs, drugs, sources]
			rt.add_row(row, {size: 18})
		end
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
