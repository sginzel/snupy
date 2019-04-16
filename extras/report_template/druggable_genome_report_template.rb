class DruggableGenomeReportTemplate < ReportTemplate
	
	def self.report_klass
		ReportEntity
	end
	
	def self.required_parameters(params)
		params.merge({
						report_druggable_only: false,
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
				[gene, records[:drugs].sort.uniq.join("; "), records[:sources].sort.uniq.join("; ")].join("\t").gsub('"', '')
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
			gene = x.delete("gene")
			gene2drug[gene] = x
		end
		
		# row for each variant
		#    Query HGVS, Gene Name, CADD Score and BAF
		#    Add drug interaction info
		
		header = %w(Variant Gene Mutation CADD DGIDB-drugs DGIDB-sources)
		rt = ReportTable.new(header)
		varids.each do |varid|
			cadd = Cadd.where(variation_id: varid, organism_id: entity.organism.id).first.phred
			var = Variation.find(varid)
			
			hgvscs = query_vep(varid).select([:gene_symbol, :transcript_id, :hgvsc]).uniq
				        .reject{|vep| vep.hgvsc.nil?}
				        .map{|vep|
					        [vep.gene_symbol, "#{vep.transcript_id}.#{vep.hgvsc})"]
				        }.uniq
			hgvscs.each do |hgnc, hgvsc|
				drugs   = (gene2drug[hgnc.upcase] || {})["drug(interaction)"]
				sources = (gene2drug[hgnc.upcase] || {})["sources"]
				if report_params["report_druggable_only"] == "1" then
					next if drugs.to_s.strip == ""
				end
				row = [var.coordinates, hgnc, hgvsc, cadd, drugs, sources]
				rt.add_row(row, {size: 18})
			end
			
		end
		rt
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
