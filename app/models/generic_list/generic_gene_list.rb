class GenericGeneList < GenericList
	
	def genes(as_hash = false)
		genes = []
		generic_list_items().each do |i|
			genes << i.value["gene"].to_s.upcase
		end
		genes.reject!{|g| g.to_s == ""}
		ret = genes.flatten.uniq
		if (as_hash)
			ret = Hash[ret.map{|g| [g, true]}]
			ret.default = false
		end
		ret
	end
	
	def ensembl_genes(as_hash = true)
		## TODO map genes in the list to valid ensembl gene ids
		ensembldb = "homo_sapiens_core_70_37"
		mygenes = genes()
		ensembl_genes = Hash[mygenes.map{|g| [g, []]}]
		ActiveRecord::Base.connection.execute(
  		sprintf("SELECT
			        display_label as alias,
			        stable_id as ensembl_gene_id
				    FROM %s.xref
				    INNER JOIN %s.object_xref ox USING (xref_id)
				    INNER JOIN %s.gene ON (%s.gene.gene_id = ox.ensembl_id)
				    WHERE display_label IN ( %s )
			", ensembldb, ensembldb, ensembldb, ensembldb, mygenes.map{|s| "'#{s}'"}.join(","))
		).each(as: :hash) do |rec|
			gene_alias = rec["alias"].upcase
			ensg = rec["ensembl_gene_id"]
			## skip records that could not be mapped
			next if ensembl_genes[gene_alias].nil?
			# ensembl_genes[gene_alias] = [] if ensembl_genes[gene_alias].nil?
			ensembl_genes[gene_alias] << rec["ensembl_gene_id"]
		end
		
		ensembl_genes.keys.each do |mygene|
			ensembl_genes[mygene].uniq!
		end
		
		if !as_hash
			ensembl_genes = ensembl_genes.values.flatten.uniq
		end
		
		return ensembl_genes
	end
	
	def create_item(record, header, cols, idxs)
		record["gene"] = cols[idxs[0]]
		record.delete(header[idxs[0]])
		GenericListItem.new(value: record)
	end
	
	def read_data_old(opts = {})
		opts = opts.reverse_merge({file: nil, idx: 0, sep: "\t", has_header: false})
		file = opts[:file]
		idx = opts[:idx].to_i
		sep = opts[:sep]
		has_header = opts[:header]
		if !file.nil? then
			content = file.read
			content.gsub!(/\r\n?/, "\n")
			items = []
			items2add = []
			lineno = 0
			header = []
			begin
				CSV.read(file, 
								 col_sep: "\t", 
								 quote_char: '"', 
								 headers: has_header, 
								 return_headers: true,
								 skip_blanks: true,
								 force_quotes: false)
				.each do |cols|
				 	if lineno == 0 then
				 		if has_header
				 			header = cols.headers
				 		else
				 			header = (0...(cols.size)).to_a.map(&:to_s)
				 		end
				 		lineno = lineno + 1
				 		next
				 	end
				 	val = Hash[header.each_with_index.map{|c,i| [header[i], cols[i].to_s.gsub("\n", " ").force_encoding("utf-8")]}]
					val["gene"] = cols[idx]
					val.delete(header[idx])
					items2add << GenericListItem.new(value: val)
					lineno = lineno + 1
				end
			rescue => e
				self.errors[:base] << e.message
				return false
			end
			
			if items2add.size > 0 then
				self.transaction do 
					self.items = [] if self.items.size > 0
					self.items = items2add
				end
			end
			
		end	
		true
	end
end