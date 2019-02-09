class GeneReportTemplate < ReportTemplate
	
	def self.report_klass
		ReportEntity
	end
	
	def self.required_parameters(params)
		params.merge({
			gene_panels: [{"id" => -1, "name" =>  "Complete Profile"}] + GenericGeneList.select([:id, :name]).map(&:attributes) #GenericGeneList.select([:id, :name])
		})
	end
	
	def report_klass
		self.class.report_klass
	end
	
	def default_attributes
		super.merge({
			identifier: "GeneReport",
			type: report_klass.name,
			xref_id: self.klass_instance.id,
			institution_id: self.klass_instance.institution.id,
			filename: "GeneReport_#{self.klass_instance.name}.docx",
			mime_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
			description: "A Gene Report generated from a query result"
		})
	end
	
	# report_info = {
	#   variation_call_ids: [],
	#   panel_ids: []
	# }
	# RETURN: A text containnig the generated report
	def report_content(entity)
		@entity = self.klass_instance
		
		tables = {}
		if report_params["gene_panels"].map(&:to_s).include?("-1") then
			tables["Profile"] = create_table(entity, nil)
		end
		GenericGeneList.where(id: report_params["gene_panels"]).each do |gl|
			tables[gl.name] = create_table(entity, gl.genes)
		end
		
		generate_docx("app/views/reports/templates/gene_report.docx.erb", report_params.merge({entity: entity, tables: tables}))
	end
	
	def create_table(entity, genes = nil)
		records = {
			transcripts: [],
			inheritance: [],
			phenotypes: []
		}
		vcids = report_params["ids"].map{|x| x.split(" | ")}.flatten
		# collect variants from variation calls
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
				Variant: var.coordinates}
			entity.specimen_probes.each do |spec|
				family_baf["#{entity.name} (#{spec.name})"] =  get_baf_in_specimen(varid, spec).round(2)
			end
			family_baf = family_baf.merge({
				Father: get_baf_in_entity(varid, entity.father).round(2),
				Mother: get_baf_in_entity(varid, entity.mother).round(2),
				Siblings: get_baf_in_entity(varid, entity.siblings).round(2)
          })
			
			transcripts = {
				Symbol: veps.map(&:gene_symbol).join(","),
				Consequence: veps.map(&:consequence).join(","),
				Transcript: veps.map(&:transcript_id).join(","),
				HGVSC: veps.map(&:hgvsc).join(","),
				Exac: veps.map{|vep| "#{vep.exac_adj_maf} (#{vep.exac_adj_allele})"}.join(","),
				dbsnp: veps.map(&:dbsnp).join(",")
			}
			
			phenotypes = {
				Variant: var.coordinates,
				CADD: Cadd.where(variation_id: varid, organism_id: entity.organism.id).first.phred,
				OMIM: veps.map(&:gene_symbol).map{|sym| OmimGenemap.where("symbol = '#{sym}' OR symbol_alias = '#{sym}'").map{|omim| "#{omim.symbol}: #{omim.phenotype} (#{omim.comments})"}}.flatten.uniq.join(","),
				Clinvar: ClinvarEvidence.where(variation_id: varid, organism_id: entity.organism.id)
					         .map{|c|
						         (c.clinvar.distance!=0)?"":"#{c.symbol}: #{c.clndn}"
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
