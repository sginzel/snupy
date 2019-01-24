class FilterAnnovarClinical < SimpleFilter
	create_filter_for QueryClinicalSignificance, :clinical,
						name: :annovar_clinvar, 
						label: "Clinical Significance (CLINVAR)",
						filter_method: :clinvar,
						organism: [organisms(:human)],
						checked: false, 
						requires: {
							Annovar => [:variant_clinical_significance]
						},
						tool: AnnovarAnnotation
	create_filter_for QueryClinicalSignificance, :clinical,
						name: :annovar_clinvar_cosmic, 
						label: "Observed in COSMIC",
						filter_method: :has_cosmic,
						organism: [organisms(:human)],
						checked: false, 
						requires: {
							Annovar => [:cosmic68_id]
						},
						tool: AnnovarAnnotation
	create_filter_for QueryClinicalSignificance, :clinical,
						name: :annovar_clinvar_patho, 
						label: "Clinical Significance (pathogenic)",
						filter_method: :clinvar_pathogenic,
						organism: [organisms(:human)],
						checked: true, 
						requires: {
							Annovar => [:variant_clinical_significance]
						},
						tool: AnnovarAnnotation

	create_filter_for QueryClinicalSignificance, :clinical_association,
										name: :annovar_clinvar_association,
										label: "Variant Clinical Significance",
										collection_method: :list_variant_clinical_significance,
										filter_method: :clinical_associaton,
										organism: [organisms(:human)],
										checked: true,
										requires: {
												Annovar => [:variant_clinical_significance]
										},
										tool: AnnovarAnnotation
	create_filter_for QueryClinicalSignificance, :clinical_association,
										name: :annovar_gwas_association,
										label: "GWAS",
										collection_method: :list_gwas,
										filter_method: :gwas,
										organism: [organisms(:human)],
										checked: true,
										requires: {
												Annovar => [:gwas_catalog]
										},
										tool: AnnovarAnnotation


	create_filter_for QueryClinicalSignificance, :clinical_disease,
						name: :annovar_clinvar_disease, 
						label: "Disease name",
						collection_method: :list_variant_disease,
						filter_method: :clinvar_disease,
						organism: [organisms(:human)],
						checked: true, 
						requires: {
							Annovar => [:variant_disease_name]
						},
						tool: AnnovarAnnotation
	
	create_filter_for QueryClinicalSignificance, :clinical_tissue,
						name: :annovar_cosmic_tissue, 
						label: "COSMIC 68 Tissue",
						filter_method: :cosmic_tissue,
						organism: [organisms(:human)],
						checked: false, 
						collection_method: :list_cosmic_tissues,
						requires: {
							Annovar => [:cosmic68_occurence]
						},
						tool: AnnovarAnnotation
	
	def clinvar(value)
		"annovars.variant_clinical_significance IS NOT NULL"
	end
	
	def has_cosmic(value)
		"annovars.cosmic68_id IS NOT NULL"
	end
	
	def clinvar_pathogenic(value)
		[
			"(annovars.variant_clinical_significance LIKE '% pathogenic%')",
			"(annovars.variant_clinical_significance LIKE '% pathogenic')"
		].join(" OR ")
	end
	
	def clinvar_disease(values)
		return nil if values.size == 0
		"(" + values.map{|v|
			"annovars.variant_disease_name RLIKE '.*#{v[1..-2].gsub('\\', '\\\\\\\\')}.*'"
		}.join(" OR ") + ")"
	end
	
	def cosmic_tissue(values)
		values.map{|value|
			"(" + ([
				"annovars.cosmic68_occurence LIKE '%#{value.gsub(/^'/,"").gsub(/'$/,"")}%'"
			].join(" OR ")) + ")"
		}.join("OR")
		
	end

	def clinical_associaton(values)
		return nil if values.size == 0
		"(" + values.map{|v|
			"annovars.variant_clinical_significance RLIKE '.*#{v[1..-2]}.*'"
		}.join(" OR ") + ")"
	end

	def gwas(values)
		return nil if values.size == 0
		"(" + values.map{|v|
			"annovars.gwas_catalog RLIKE '.*#{v[1..-2]}.*'"
		}.join(" OR ") + ")"
	end

	def list_cosmic_tissues(params)
		ret = Annovar.uniq.pluck(:cosmic68_occurence).reject(&:nil?).sort.map{|c|
			myret = []
			c.split(",").each do |cosmstr|
				occurence, tissue = cosmstr.scan(/([0-9]*)\((.*)\)/).flatten
				myret << {
					id: tissue,
					tissue: tissue
				}
			end
			myret
		}.flatten.uniq.reject{|rec| rec[:id].nil?}
		ret.sort{|x,y| x[:id].to_s <=> y[:id].to_s}
	end

	def list_attribute(attr, sep = nil, &block)
		ret = Annovar.uniq(attr).pluck(attr).reject(&:nil?).map{|v|
			if block_given?
				v = yield v
			end
			if !sep.nil? then
				if (sep.is_a?(String))
					v.strip.split(sep)
				else
					v.strip.gsub(sep, "#\\1").split("#")
				end
			else
				v
			end
		}.flatten.sort.uniq
		ret.map{|v|
			{
					id: v,
					label: v,
					name: attr
			}
		}
	end

	def list_variant_disease(params)
		list_attribute(:variant_disease_name, /,([A-Z&])/) {|v|
			v = v.gsub("not_provided", "Not_provided")
			.gsub("not_specified", "Not_specified")
			.gsub("delta", "Delta")
			.gsub("beta", "Beta")
			v[0] = v[0].upcase
			v
		}
	end

	def list_variant_clinical_significance(params)
		list_attribute(:variant_clinical_significance, ",")
	end

	def list_gwas(params)
		list_attribute(:gwas_catalog, /,([A-Z&])/)
	end

end