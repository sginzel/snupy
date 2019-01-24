# == Description
# Helper Module
module ExperimentsHelper
	
	def get_from_param(*args)
		ret = params.dup()
		args.each do |key|
			return nil if ret[key].nil?
			ret = ret[key]
		end
		ret
	end
	
	# creates an array that represents one row of a VCF
	def create_vcf_result(aggregation_result, smpls)
		# group varcalls by region
		return ["NOT IMPLEMENTED YET"] if 1 == 1
		records = {}
		varcalls.each do |rec|
			key = "#{rec["regions.name"]}:#{rec["regions.start"]}"
			if records[key].nil? then
				if !(rec["variation_annotations.existing_variation"].to_s == "") then
					rsid = YAML.load(rec["variation_annotations.existing_variation"]).first
				else
					rsid = "."
				end
				records[key] = {
						chr: rec["regions.name"],
						pos: rec["regions.start"],
						id: rsid,
						ref: rec["alterations.ref"],
						alt: [],
						qual: [],
						filter: ".",
						info: [],
						format: "GT:AD:BAF:DP:GQ",
						samples: {}
				}
			end
			records[key][:alt] << rec["alterations.alt"]
			records[key][:qual] << rec["variation_calls.qual"]
			records[key][:info] << {
					genes: rec["genetic_elements.ensembl_gene_id"],
					features: rec["genetic_elements.ensembl_feature_id"],
					consequence: rec["consequences.consequence"],
					gmaf: (rec["variation_annotation.gmaf"] || ".")
			}
			records[key][:samples][rec["samples.nickname"]] = [
					rec["variation_calls.gt"],
					"#{rec["variation_calls.ref_reads"]},#{rec["variation_calls.alt_reads"]}",
					((rec["variation_calls.alt_reads"])/(rec["variation_calls.ref_reads"] + rec["variation_calls.alt_reads"] + (10**-32).to_f)).round(3),
					(rec["variation_calls.dp"] || 0),
					rec["variation_calls.gq"]
			].join(":")
		end
		## post process
		records.keys.each do |key|
			records[key][:alt] = records[key][:alt].uniq.join(",")
			records[key][:qual] = records[key][:qual].min
			# set info field to correct format
			tmp = records[key][:info].uniq.map{|gene_and_cons| [gene_and_cons[:features], gene_and_cons[:consequence]]}.uniq
			genes = records[key][:info].map{|gene_and_cons| gene_and_cons[:genes]}.uniq
			features = tmp.map{|g|g[0]}
			consequences = tmp.map{|g|g[1]}
			num_fatal = [consequences.select{|c| Consequence::FATAL.include?(c)}.size]
			gmaf = records[key][:info].map{|gene_and_cons| gene_and_cons[:gmaf]}.uniq
			records[key][:info] = {fatal: num_fatal, genes: genes, features: features, consequences: consequences, gmaf: gmaf}
		end

		ret = []
		records.each do |key, rec|
			ret << [
					rec[:chr],
					rec[:pos],
					rec[:id],
					rec[:ref],
					rec[:alt],
					rec[:qual],
					rec[:filter],
					rec[:info].map{|k,v|"#{k.upcase}=#{v.join(",")}"}.join(";"),
					rec[:format],
					smpls.map{|smpl|
						smplrec = rec[:samples][smpl.nickname]
						smplrec = ["0/0:0,0:0:0:0"] if smplrec.nil?
						smplrec
					}.join("\t")
			].join("\t")
		end
		ret.sort!{|x,y|
			x = x.split("\t")
			y = y.split("\t")
			d sprintf("%s:%d <=> %s:%d\n", x[0], x[1].to_i, y[0], y[1].to_i)
			chrx = x[0]
			chry = y[0]
			chrx = 23 if chrx == "X"
			chry = 23 if chry == "X"
			chrx = 24 if chrx == "Y"
			chry = 24 if chry == "Y"
			chrx = chrx.to_i
			chry = chry.to_i

			if chrx == chry then
				x[1].to_i <=> y[1].to_i
			else
				chrx <=> chry
			end
		}
		ret
	end

	def region_list_to_variants(ids)
		regions2search = ids
		regions2search = [regions2search] unless regions2search.is_a?(Array)
		@regions = []
		regions2search.each do |region|
			chr, start, stop = region.split(/[[:punct:]]/).first(3)
			@regions << Region.where("name = ? AND start BETWEEN ? AND ? AND stop BETWEEN ? AND ?",
									 chr, start, stop, start, stop)
		end
		@regions = @regions.flatten.uniq
		@variations = @regions.map{|r| r.overlapping_variations}.flatten.uniq
		@variations
	end
	
	def get_interactions_from_db(genes, threshold, organism_id, include_textmining = false)
		tmfilter = "(neighborhood > #{threshold} OR neighborhood_transferred > #{threshold} OR fusion > #{threshold} OR cooccurence > #{threshold} OR homology > #{threshold} OR coexpression > #{threshold} OR coexpression_transferred > #{threshold} OR experiments > #{threshold} OR experiments_transferred > #{threshold} OR `database` > #{threshold} OR database_transferred > #{threshold})"
		tmfilter = "" if include_textmining
		gene2string = Hash[genes.map{|g| [g, nil]}]
		string2input = {}
		StringProteinAliasName.where(alias: genes, organism_id: organism_id).each do |span|
			gene2string[span[:alias]] = span.stringdb_id
			string2input[span.stringdb_id] = span[:alias]
		end
		# get string proteins for input
		strings = StringProtein.where(stringdb_id: gene2string.values.flatten.uniq.reject(&:nil?))
		string_ids = strings.pluck("stringdb_id").uniq
		links = Aqua.scope_to_array (
									StringProteinLink.where("stringdb1_id IN (?) OR stringdb2_id IN (?)", string_ids, string_ids)
										.where("combined_score > #{threshold }")
										.where(tmfilter)
										.select([:stringdb1_id, :stringdb2_id, :combined_score])
									)
		link_nodes = links.map {|rec|
			[rec["stringdb1_id"], rec["stringdb2_id"], rec["combined_score"]]
		}.uniq
		# get string objects for all links so we can create a full set of nodes
		string_ids = links.map{|rec| [rec["stringdb1_id"], rec["stringdb2_id"]]}.flatten.uniq
		strings = StringProtein.where(stringdb_id: string_ids)
		strings2symbol = Hash[string_ids.map{|x| [x, x]}]
		res = Aqua.scope_to_array ( StringProteinAliasName.where(stringdb_id: string_ids, organism_id: organism_id).where("SOURCE LIKE '%GN'"))
		res.each{|rec|
			next if (not strings2symbol[rec["stringdb_id"]].nil?) and (not strings2symbol[rec["stringdb_id"]] == rec["stringdb_id"])
			strings2symbol[rec["stringdb_id"]] = rec["alias"]
		}
		nodes = strings.map{|n|
			{
				gene: n.stringdb_id,
				alias:  strings2symbol[n.stringdb_id],
				group: "none",
				url: ""
			}
		}
		
		edges = link_nodes.map{|from, to, score|
			{
				source: from,
				target: to,
				source_symbol: strings2symbol[from],
				target_symbol: strings2symbol[to],
				value: (score).to_i
			}
		}
		{
			nodes: nodes,
			edges: edges,
			input2string: gene2string,
			string2input: string2input,
			strings2symbol: strings2symbol
		}
		
		
	end
	
	
	def get_interaction_data(params)
		
		vcids = params[:ids].split(" | ")
		varids = VariationCall.where(id: vcids).pluck(:variation_id)
		
		@experiment = Experiment.find(params[:experiment])
		@organism = @experiment.organism
		interactions = {}
		string_partners = {}
		threshold = (params[:threshold] || 950).to_i
		list_network = {nodes: [], edges: [], input2string: {}, string2input: {}, strings2symbol: {}}
		if !params[:list].nil? and params[:list].to_i != 0 then
			@listgenes = GenericGeneList.find(params[:list]).genes
			list_network = get_interactions_from_db(@listgenes, threshold, @organism.id, params[:include_interaction_between_list_items] == "yes")
		else
			@listgenes = []
		end
		
		@selected_genes = {}
		Aqua.scope_to_array(Vep::Ensembl.where(variation_id: varids).select([:variation_id, :gene_id])).uniq.each do |rec|
			@selected_genes[rec["gene_id"]] ||= []
			@selected_genes[rec["gene_id"]] << rec["variation_id"]
			@selected_genes[rec["gene_id"]].uniq!
		end
		selected_network = get_interactions_from_db(@selected_genes.keys, threshold, @organism.id, params[:include_interaction_between_list_items] == "yes")
		
		
		network = {
			nodes: (list_network[:nodes] + selected_network[:nodes]).uniq,
			edges: (list_network[:edges] + selected_network[:edges]).uniq,
			input2string: (list_network[:input2string].merge selected_network[:input2string]),
			string2input: (list_network[:string2input].merge selected_network[:string2input]),
			strings2symbol: (list_network[:strings2symbol].merge selected_network[:strings2symbol])
		}
		
		## set the groups correctly
		network[:nodes].each do |n|
			n[:group] = "Interactions_partners" if not list_network[:string2input][n[:gene]].nil?
			n[:group] = "Target_genes" if not selected_network[:string2input][n[:gene]].nil?
			n[:group] = "both" if not selected_network[:string2input][n[:gene]].nil? and not list_network[:string2input][n[:gene]].nil?
			if not selected_network[:string2input][n[:gene]].nil? then
				vars = @selected_genes[selected_network[:string2input][n[:gene]]]
				n[:url] = "VARIDS: #{(vars || []).join(" | ")}"
			end
		end
		
		# clear empty nodes and those which have no intersting connection
		node_count = Hash.new(0)
		network[:edges].each do |e|
			# node_count[e[:source]] += 1
			node_count[e[:target]] += 1
		end
		
		network[:nodes].select!{|n|
			node_count[n[:gene]] > 0 and (node_count[n[:gene]] > 1 or n[:group] != "none")
		}
		node_present = Hash[network[:nodes].map{|n| [n[:gene], true]}]
		node_present.default = false
		network[:edges].select!{|e|
			node_present[e[:source]] && node_present[e[:target]]
		}
		
		url_template = interaction_details_experiments_path
		
		labels = Hash[network[:edges].map{|n|
			[n[:gene], n[:alias]]
		}]
		missing = []
		
		###set colors
		colors = {
			Target_genes: "#6495ED",
			Interactions_partners:"#E9967A",
			both:"#6A5ACD",
			none: "#AAAAAA"
		}
		colors.default = "#000000"
		
		width, height = params[:dimension].to_s.gsub(" ", "").split(",")[0..1]
		width = 1024 if width.nil?
		height = (width.to_i * 0.75).round(0) if height.nil?
		return {
			edges: network[:edges],
			nodes: network[:nodes],
			url_template: url_template,
			colors: colors,
			groups: [],
			labels: labels,
			width: width,
			height: height,
			experiment: params[:experiment],
			missing: missing
		}
	end
	
	def get_interaction_data_thais(params)
		
		alias_table = "stringdb.protein_alias"
		alias_stringdb_id = "stringdb"
		link_table = "stringdb.protein_links"
		link_experiment = "experimental"
		alias_table = "string_protein_alias"
		alias_stringdb_id = "stringdb_id"
		link_table = "string_protein_links"
		link_experiment = "experiments"
		
		if params[:ids].all?{|id| id =~ /[0-9XYM]+[:punct:][0-9]+[:punct:][0-9]+/} then
		### determine genes and interactions that belong to the given regions
		## given regions
				regions2search = params[:ids]
				regions2search = [regions2search] unless regions2search.is_a?(Array)
				@regions = []
				regions2search.each do |region|
					chr, start, stop = region.split(/[[:punct:]]/).first(3)
					@regions << Region.where("name = ? AND start BETWEEN ? AND ? AND stop BETWEEN ? AND ?",
											 chr, start, stop, start, stop)
				end
				@regions = @regions.flatten.uniq
		
		# Find variations to a given region
				@variations = @regions.map{|r| r.overlapping_variations}.flatten.uniq
		else
			vcids = params[:ids].split(" | ")
			varids = VariationCall.where(id: vcids).pluck(:variation_id)
			@regions = Region.joins(:variations).where("variations.id" => varids)
			@variations = Variation.find(varids)
		end
		
		# @variation_annotation = VariationAnnotation.includes(:genetic_element).find_all_by_variation_id(@variations.map(&:id))
		
# Find gene to a given variation annotation
		# @genes = @variation_annotation.map{|va| va.genetic_element.ensembl_gene_id}.reject(&:nil?).uniq
		@genes = Vep::Ensembl.where(variation_id: @variations).pluck(:gene_id).uniq
		if !params[:list].nil? and params[:list].to_i != 0 then
			@listgenes = GenericGeneList.find(params[:list]).ensembl_genes(false)
		else
			@listgenes = []
		end

		
# Find symbols to genes and listgenes
		symbols = Hash[
				GeneticElement.ensembl_to_symbol([@genes, @listgenes].flatten.uniq).map{|ensg, symbols|
					[ensg, symbols.join("/")]
				}
		]

### find interactions of list genes with any of the selected genes
## find stringdb ids

# find stringdb ids from genes_alias
		genes_alias = ActiveRecord::Base.connection.execute(sprintf("
			SELECT #{alias_stringdb_id} AS stringdb, alias FROM #{alias_table}
			WHERE #{alias_stringdb_id} LIKE '9606.%%'
			AND alias IN (%s)
			AND (source LIKE 'Ensembl %%' OR source LIKE '%% Ensembl' OR source LIKE '%% Ensembl %%' OR source LIKE 'Ensembl')
			", @genes.map{|g| "'#{g}'"}.join(","))).each(as: :hash)
		temp_genes_alias = genes_alias.dup;
		genes_alias = Hash[genes_alias.map{|r| [r["stringdb"], r["alias"]]}]


# find stringdb ids from listgenes_alias
		listgenes_alias = ActiveRecord::Base.connection.execute(sprintf("
			SELECT #{alias_stringdb_id} AS stringdb, alias FROM #{alias_table}
			WHERE #{alias_stringdb_id} LIKE '9606.%%'
			AND alias IN (%s)
			AND (source LIKE 'Ensembl %%' OR source LIKE '%% Ensembl' OR source LIKE '%% Ensembl %%' OR source LIKE 'Ensembl')
		", @listgenes.map{|g| "'#{g}'"}.join(","))).each(as: :hash)
		temp_listgenes_alias = listgenes_alias.dup;
		listgenes_alias = Hash[listgenes_alias.map{|r| [r["stringdb"], r["alias"]]}]


### map stringdb IDs to gene symbols
		labels = {}
		genes_alias.each do |strindbid, ensgid|
			labels[strindbid] = symbols[ensgid].to_s
		end

		listgenes_alias.each do |strindbid, ensgid|
			labels[strindbid] = symbols[ensgid].to_s
		end


### find genes that could not be mapped
		genes_alias_missing = @genes.dup
		listgenes_alias_missing = @listgenes.dup
		genes_alias.each{|strindb, ensgid|
			genes_alias_missing.delete(ensgid)
		}
		listgenes_alias.each{|strindb, ensgid|
			listgenes_alias_missing.delete(ensgid)
		}
		missing = [genes_alias_missing, listgenes_alias_missing].flatten.uniq
		missing = missing.map{|ensg| {Gene: ensg, symbol: symbols[ensg]}}

## Check if we want text mining results or not
		if params[:include_text_mining] == "yes" then
			tmfilter = ""
		else
			tmfilter = "AND (neighborhood > 0 OR fusion > 0 OR cooccurence > 0 OR #{link_experiment} > 0 OR `database` > 0)"
		end

## Check if we want to include interaction between list items
		if params[:include_interaction_between_list_items] == "yes" then
			stringdbids1 = [genes_alias.keys, listgenes_alias.keys].flatten.uniq
			stringdbids2 = [genes_alias.keys, listgenes_alias.keys].flatten.uniq
		else
			stringdbids1 = [listgenes_alias.keys].flatten.uniq
			stringdbids2 = [genes_alias.keys].flatten.uniq
		end

## find interactions between the genes in both lists
		if stringdbids1.size > 0 then
			interactions = ActiveRecord::Base.connection.execute(sprintf("
			SELECT stringdb1_id, stringdb2_id, combined_score FROM #{link_table}
			WHERE stringdb1_id IN (%s) AND stringdb2_id IN (%s)
				AND combined_score >= %d
				%s
			", stringdbids1.map{|sid| "'#{sid}'"}.join(","),
																		 stringdbids2.map{|sid| "'#{sid}'"}.join(","),
																		 params[:threshold].to_i,
																		 tmfilter
																 )).each(as: :hash)
		else
			interactions = []
		end

###compute nodes and links

##compute nodes from db results
# No overlap between gene panels and query genes =>
# query genes: group 1
# genes panels: group 2

		nodes_temp_genes_alias = Hash.new(0)
		temp_genes_alias.map { |node|
			if(nodes_temp_genes_alias[node["stringdb"]] == 0) then
				nodes_temp_genes_alias[node["stringdb"]]  =  {
						gene: node["stringdb"],
						alias:  node["alias"],
						group:"Target_genes",
						url: "http://www.genecards.org/cgi-bin/carddisp.pl?gene=#{node["alias"]}"
				}
			else
				if(!((nodes_temp_genes_alias[node["stringdb"]][:alias]).to_s).include? (node["alias"].to_s)) then
					temp = [(nodes_temp_genes_alias[node["stringdb"]][:alias]) , node["alias"]].join ("-")
					nodes_temp_genes_alias[node["stringdb"]]  =   {
							gene: node["stringdb"],
							alias:  temp,
							group:"Target_genes",
							url: "http://www.genecards.org/cgi-bin/carddisp.pl?gene=#{temp}"
					}
				end
			end
		}

		nodes_temp_listgenes_alias = Hash.new(0)
		temp_listgenes_alias.map { |node|
			if(nodes_temp_listgenes_alias[node["stringdb"]] == 0) then
				nodes_temp_listgenes_alias[node["stringdb"]]  =  {
						gene: node["stringdb"],
						alias:  node["alias"],
						group:"Interactions_partners",
						url: "http://www.genecards.org/cgi-bin/carddisp.pl?gene=#{node["alias"]}"
				}
			else
				if(!((nodes_temp_listgenes_alias[node["stringdb"]][:alias]).to_s).include? (node["alias"].to_s)) then
					temp = [nodes_temp_listgenes_alias[node["stringdb"]][:alias] , node["alias"]].join ("-")
					nodes_temp_listgenes_alias[node["stringdb"]] = {
							gene: node["stringdb"],
							alias:  temp,
							group:"Interactions_partners",
							url: "http://www.genecards.org/cgi-bin/carddisp.pl?gene=#{temp}"
					}
				end
			end
		}

# Overlap between gene panels and query genes => genes are in group 3
		nodes_temp_genes_alias.each do |key1,value1|
			nodes_temp_listgenes_alias.each do |key2,value2|
				if(key1.to_s.eql?(key2.to_s))
					value1[:group] = "both"
					value2[:group] = "both"
				end
			end
		end

		nodes_temp = nodes_temp_genes_alias.merge (nodes_temp_listgenes_alias)


##compute links from interactions list
		edges = interactions.map{|rec|{
				source: rec["stringdb1_id"],
				target: rec["stringdb2_id"],
				source_symbol: labels[rec["stringdb1_id"]],
				target_symbol: labels[rec["stringdb2_id"]],
				value: rec["combined_score"]
		}}

###Filter nodes without interactions
		filtered_nodes = Hash.new(0)
		nodes_temp.each {  |key, value|
			interactions.map { |rec|
				if (key.include?rec["stringdb1_id"]) || (key.include?rec["stringdb2_id"])
					filtered_nodes[key] = value
				end
			}
		}
		nodes = filtered_nodes.values
###set url
		url_template = interaction_details_experiments_path

###set colors
		colors = {
				Target_genes: "#6495ED",
				Interactions_partners:"#E9967A",
				both:"6A5ACD"
		};

		##Compute groups
		groups = Hash.new(0)
		nodes_temp.each do |key,value|
			groups[key] ={
					stringdb_id: key,
					group: value[:group],
					label: value[:alias]
			}
		end
		groups = groups.values

		width, height = params[:dimension].to_s.gsub(" ", "").split(",")[0..1]
		width = 1024 if width.nil?
		height = (width.to_i * 0.75).round(0) if height.nil?
		return {
				edges: edges,
				nodes: nodes,
				url_template: url_template,
				colors: colors,
				groups: groups,
				labels: labels,
				width: width,
				height: height,
				experiment: params[:experiment],
				missing: missing
		}
	end

	def get_xls(tbl, params, title)
		raise NotImplementedError.new("get_xls method is not implemented yet.")
		# require "spreadsheet"
		# content = get_table_content(tbl, selected_samples, selected_question, selected_filter, tbl_sampels)
		content = [params, tbl]
		io = StringIO.new
		workbook = Spreadsheet::Workbook.new(io)
		worksheet = workbook.create_worksheet(name: "SNuPy - #{title}")
		rowno = 0
		content.each do |section, rows|
			## write section title
			if section.is_a?(String)
				worksheet.write(rowno, 0, section.to_s)
				rowno += 1
			end
			rows.each do |row|
				row.each_with_index do |coltext, colno|
					col_linked = self.class.helpers.link_identifier(coltext.to_s.gsub('"', "")).to_s
					d col_linked
					d col_linked.scan(/href=["'](.*?)["' >]/)
					if col_linked =~ /^<a href.*/ then
						url = col_linked.scan(/href=["'](.*?)["' >]/).flatten.first
						# worksheet.write rowno, colno, (Spreadsheet::Link.new url, coltext.to_s.gsub('"',""))
						url = "http://this.link.was.not.recognized" if url.nil?
						if coltext =~ /^<a href.*/ then
							coltext = coltext.scan(/>(.*)<\/a>/).flatten.first
						end
						coltext = "" if coltext.nil?
						worksheet[rowno, colno] = Spreadsheet::Link.new url, coltext.to_s.gsub('"',"")
					else
						# worksheet.write(rowno, colno, col_linked)
						worksheet[rowno, colno] = col_linked
					end
					worksheet[rowno, colno] = "NA" if worksheet[rowno, colno].nil?
				end
				rowno += 1
			end
		end
		workbook.write io
		io.string

	end
end
