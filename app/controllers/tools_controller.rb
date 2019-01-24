#Author::  Schlee-Guimaraes
class ToolsController < ApplicationController
	
	def ppi_network
		@edges = {}
		@nodes = {}
		@groups = {}
		@missing = {}
		@help = ""
		
		alias_table = "stringdb.protein_alias"
		alias_stringdb_id = "stringdb"
		link_table = "stringdb.protein_links"
		link_experiment = "experimental"
		alias_table = "string_protein_alias" # new String Import
		alias_stringdb_id = "stringdb_id"
		link_table = "string_protein_links" # new String Import
		link_experiment = "experiments"
		
### Query Genes
		genes_alias = {}
		filter_keys = {}
		genes_list_alias_keys = {}
		genes_list_alias_text_keys = {}
		if (!params[:genesinput].to_s.empty?)
      genes_input = params[:genesinput].split(/[\s\.]/)
			@help = " input ist nicht null"
			genes_alias = ActiveRecord::Base.connection.execute(sprintf(
				"SELECT #{alias_stringdb_id} AS stringdb, alias FROM #{alias_table}
				WHERE #{alias_stringdb_id} LIKE '9606.%%'
				AND alias IN (%s)
				",
				genes_input.map{|g| "'#{g}'"}.join(","))).each(as: :hash)

			genes_alias_dup = genes_alias.dup;

			genes_alias = Hash[genes_alias.map{|r| [r["stringdb"], r["alias"]]}]

			genes_alias_keys = genes_alias.keys

			filter_keys = [genes_alias_keys].flatten.uniq.compact

### Gene panels from list
			if (!params[:genelistfilter].to_s.blank?)
				gene_list = params[:genelistfilter]
				gene_lists_ids = GenericGeneList.find_all_by_id(gene_list)
				gene_lists_input = gene_lists_ids.map{|gl| gl.items.map{|gli| gli.value["gene"]}}.flatten.uniq

				genes_list_alias = {}
				genes_list_alias = ActiveRecord::Base.connection.execute(sprintf(
					"SELECT #{alias_stringdb_id} AS stringdb, alias FROM #{alias_table}
						WHERE #{alias_stringdb_id} LIKE '9606.%%'
						AND alias IN (%s)
						",
						gene_lists_input.map{|g| "'#{g}'"}.join(","))).each(as: :hash)

				genes_list_alias_dup = genes_list_alias.dup

				genes_list_alias = Hash[genes_list_alias.map{|r| [r["stringdb"], r["alias"]]}]

				genes_list_alias_keys = genes_list_alias.keys
				filter_keys = [genes_list_alias_keys , genes_list_alias_text_keys].flatten.uniq.compact
			end

### Gene panels from text input
			if (!params[:genesfilter].to_s.blank?)
				genes_list_alias_text_input = params[:genesfilter].split("\r\n")
				genes_list_alias_text = {}
				genes_list_alias_text = ActiveRecord::Base.connection.execute(sprintf(
				"SELECT #{alias_stringdb_id} AS stringdb, alias FROM #{alias_table}
				WHERE #{alias_stringdb_id} LIKE '9606.%%'
				AND alias IN (%s)
				",
				genes_list_alias_text_input.map{|g| "'#{g}'"}.join(","))).each(as: :hash)

				genes_list_alias_text_dup = genes_list_alias_text.dup

				genes_list_alias_text = Hash[genes_list_alias_text.map{|r| [r["stringdb"], r["alias"]]}]

				genes_list_alias_text_keys = genes_list_alias_text.keys
				filter_keys = [genes_list_alias_keys , genes_list_alias_text_keys].flatten.uniq.compact

			end

##Set filters based on fixed gene panels
			filter_alias = {}
			filter_alias = [genes_list_alias_dup , genes_list_alias_text_dup].flatten.uniq.compact

## find genes that could not be mapped
# Find symbols to genes and listgenes
			genes_alias_missing = genes_input.dup
			genes_alias.map { |key, value|
				genes_alias_missing.delete_if{|gene|(gene.casecmp(value)==0)}
			}

			if !params[:genelistfilter].to_s.blank?
				filter_genes_list_alias_missing = gene_lists_input
				genes_list_alias.map { |key, value|
					filter_genes_list_alias_missing.delete_if{|gene|(gene.casecmp(value)==0)}
				}
			end

			if !params[:genesfilter].to_s.blank?
				filter_genes_list_alias_text_missing = genes_list_alias_text_input
				genes_list_alias_text.map { |key, value|
					filter_genes_list_alias_text_missing.delete_if{|gene|(gene.casecmp(value)==0)}
				}
			end

			@missing = [genes_alias_missing,filter_genes_list_alias_missing ,filter_genes_list_alias_text_missing ].flatten.uniq
			@missing = @missing.map{|ensg| {Gene: ensg}}

##Set typ interactios

			if params[:interaction_between_list_items] == "0"
				stringdbids1 = [genes_alias_keys,filter_keys].flatten.uniq
				stringdbids2 = [genes_alias_keys,filter_keys].flatten.uniq
			else
				stringdbids1 = [genes_alias_keys].flatten.uniq
				stringdbids2 = [filter_keys].flatten.uniq
			end

### find interactions between the genes in both lists
			tmfilter = ""
## Check if we want text mining results or not
			if params[:all] == "1"then
				tmfilter = " AND (textmining != 0)"
			end

# Check if we want text mining results or not
			if params[:textmining] == "1"then
				tmfilter += " AND (textmining > 0)"
			end

# Check if we want neighborhood results or not
			if params[:neighborhood] == "1"then
				tmfilter += " AND (neighborhood > 0)"
			end

# Check if we want fusion results or not
			if params[:fusion] == "1"then
				tmfilter += " AND (fusion > 0)"
			end

# Check if we want cooccurence results or not
			if params[:cooccurence ] == "1"then
				tmfilter += " AND (cooccurence  > 0)"
			end

# Check if we want experimental results or not
			if params[:experimental] == "1"then
				tmfilter += " AND (#{link_experiment} > 0)"
			end

# Check if we want database results or not
			if params[:database] == "1"then
				tmfilter += " AND (`database`> 0)"
			end

###Check if score was fixed
			if params[:scoretext].to_s.blank? || params[:scoretext].to_s.blank?
				score = "0"
			else
				score = params[:scoretext]
			end

### Get interactions from db

			if stringdbids1.size > 0 then
				interactions = ActiveRecord::Base.connection.execute(sprintf("
				SELECT stringdb1_id, stringdb2_id, combined_score FROM #{link_table}
				WHERE stringdb1_id IN (%s) AND stringdb2_id IN (%s)
				AND combined_score >= %d
				%s
				", stringdbids1.map{|sid| "'#{sid}'"}.join(","),
				stringdbids2.map{|sid| "'#{sid}'"}.join(","),
				score.to_i,
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
      genes_alias_dup.map { |node|
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

			nodes_temp_filter_alias = Hash.new(0)
			filter_alias.map { |node|
				if(nodes_temp_filter_alias[node["stringdb"]] == 0) then
					nodes_temp_filter_alias[node["stringdb"]]  =  {
						gene: node["stringdb"],
						alias:  node["alias"],
						group:"Interactions_partners",
						url: "http://www.genecards.org/cgi-bin/carddisp.pl?gene=#{node["alias"]}"
					};
				else
					if(!((nodes_temp_filter_alias[node["stringdb"]][:alias]).to_s).include? (node["alias"].to_s)) then
						temp = [nodes_temp_filter_alias[node["stringdb"]][:alias] , node["alias"]].join ("-")
						nodes_temp_filter_alias[node["stringdb"]] = {
							gene: node["stringdb"],
							alias:  temp,
							group:"Interactions_partners",
							url: "http://www.genecards.org/cgi-bin/carddisp.pl?gene=#{temp}"
						}
					end
				end
			}

# Overlap between gene panels and query genes => genes are in group 3
			nodes_temp_filter_alias.each do |key1,value1|
				nodes_temp_genes_alias.each do |key2,value2|
					if(key1.to_s.eql?(key2.to_s))
						value1[:group] = "both"
						value2[:group] = "both"
					end
				end
			end

			nodes_temp = nodes_temp_genes_alias.merge (nodes_temp_filter_alias)


##Compute groups
			groups = Hash.new(0)
			nodes_temp.each do |key,value|
				groups[key] = {
					stringdb_id: key,
					group: value[:group],
					label: value[:alias]
				}
			end
			@groups = groups.values

###compute links from interactions list
			edgesTemp = Hash.new(0)
			interactions.map{|rec|
				if( edgesTemp[ [rec["stringdb2_id"],rec["stringdb1_id"] ].join ("-")] == 0 )
					if (edgesTemp[ [rec["stringdb1_id"],rec[ "stringdb2_id" ] ].join ("-")] == 0)
						edgesTemp[ [rec["stringdb1_id"],rec[ "stringdb2_id" ] ].join ("-")] = {
							source: rec["stringdb1_id"],
							target: rec["stringdb2_id"],
							value: rec["combined_score"]
						}
					end
				end
			}
###Filter nodes without interactions
			filtered_nodes = Hash.new(0)
			nodes_temp.each {  |key, value|
				edgesTemp.each_key{|rec|
						if rec.include?(key)
							filtered_nodes[key] = value
						end
				}
			}
###set nodes and edges
			@nodes = filtered_nodes.values
			@edges= edgesTemp.values
###set url
			@url_template = "gene_details"

###set colors
			@colors = {
					Target_genes: "#6495ED",
					Interactions_partners:"#E9967A",
					both:"6A5ACD"
			};
		end
	end

	def gene_details
		@gene_symbol = params[:alias]
		@gene_cards = params[:url]


		@node_table_id = "node_table_#{Time.now().to_f.to_s.gsub(".", "")}"
		@gene_details = {
			gene: params[:genes],
			alias: params[:alias],
			group: params[:group]
		}

		render(partial: tools_gene_details_path, locals: {
			gene_symbol:  @gene_symbol,
			node_table_id: @node_table_id,
			gene_details: @gene_details
		})
	end
end