class StringProtein < ActiveRecord::Base
	self.table_name = "string_proteins"
	# self.primary_key = "stringdb_id" # this must not be used...
	
	has_many :vep, class_name: "Vep::Ensembl", primary_key: "ensembl_protein_id", foreign_key: "protein_id", readonly: true
	has_many :variations, through: :vep, readonly: true
	has_many :variation_calls, through: :variations, readonly: true
	
	attr_accessible :stringdb_id, :ensembl_protein_id, :taxon_id, :organism_id
	
	# using has_and_belongs_to_many does not work because it requires a different primary key to be set, but this is not supported.
	#has_and_belongs_to_many :string_proteins, 
	#	join_table: :string_protein_links,
	#	# primary_key: "stringdb_id", 
	#	foreign_key: "stringdb1_id",
	#	association_foreign_key: "stringdb2_id",
	#	readonly: true
	#has_and_belongs_to_many :partners,
	#	class_name: "StringProtein",
	#	join_table: :string_protein_links,
	#	# primary_key: "stringdb_id", 
	#	foreign_key: "stringdb1_id",
	#	association_foreign_key: "stringdb2_id",
	#	readonly: true
	
	has_many :string_protein_links, 
		class_name: "StringProteinLink", 
		primary_key: "stringdb_id", 
		foreign_key: "stringdb1_id",
		readonly: true
	has_many :string_protein_links_from, 
		class_name: "StringProteinLink", 
		primary_key: "stringdb_id", 
		foreign_key: "stringdb1_id",
		readonly: true
	has_many :string_protein_links_to, 
		class_name: "StringProteinLink", 
		primary_key: "stringdb_id", 
		foreign_key: "stringdb2_id",
		readonly: true
	alias :links :string_protein_links
	
	has_many :string_protein_actions, 
		class_name: "StringProteinAction", 
		primary_key: "stringdb_id", 
		foreign_key: "stringdb1_id",
		readonly: true#, :conditions => ['string_protein_actions.a_is_acting = ?', 1]
	has_many :acting_string_protein_actions, 
		class_name: "StringProteinAction", 
		primary_key: "stringdb_id", 
		foreign_key: "stringdb1_id",
		readonly: true, :conditions => ['string_protein_actions.a_is_acting = ?', 1] 
	has_many :affecting_string_protein_actions, 
		class_name: "StringProteinAction", 
		primary_key: "stringdb_id", 
		foreign_key: "stringdb2_id",
		readonly: true, :conditions => ['string_protein_actions.a_is_acting = ?', 1]
	alias :actions :string_protein_actions
	
	has_many :string_protein_alias_names, 
		primary_key: "stringdb_id", 
		foreign_key: "stringdb_id",
		readonly: true
	has_many :alias,
		primary_key: "stringdb_id", 
		foreign_key: "stringdb_id",
		class_name: "StringProteinAliasName",
		readonly: true
	
	has_many :links_to, 
		class_name: "StringProtein", 
		through: 		:string_protein_links_to, 
		source: 		:source, 
		readonly: true do 
			def highest
				where("string_protein_links.combined_score > 900")
			end
			def high
				where("string_protein_links.combined_score > 700")
			end
			def medium
				where("string_protein_links.combined_score > 400")
			end
			def low
				where("string_protein_links.combined_score > 150")
			end
	end
	has_many :links_from, 
		class_name: "StringProtein", 
		through: 		:string_protein_links_from, 
		source: 		:sink, 
		readonly: true do 
			def highest
				where("string_protein_links.combined_score > 900")
			end
			def high
				where("string_protein_links.combined_score > 700")
			end
			def medium
				where("string_protein_links.combined_score > 400")
			end
			def low
				where("string_protein_links.combined_score > 150")
			end
	end
		
	
	has_many :acts_on, 
		class_name: "StringProtein", 
		through: 		:acting_string_protein_actions, 
		source: 		:sink, 
		readonly: true
	has_many :affected_by, 
		class_name: "StringProtein", 
		through: 		:affecting_string_protein_actions, 
		source: 		:source, 
		readonly: true
	
	def self.symbols(strindb_ids, as_hash = true)
		res = StringProteinAliasName.where(strindb_id: strindb_ids).where("SOURCE LIKE '%GN'")
		if !as_hash then
			ret = res.pluck(:alias).uniq
		else
			ret = {}
			res.each do |span|
				ret[span.stringdb_id] = [] if ret[span.stringdb_id].nil?
				ret[span.stringdb_id] << span.alias
			end
		end
		ret
	end
	
	# has_many :partners, through: :string_protein_links
	def symbol(db = ['Ensembl_HGNC', 'Ensembl_HGNC_curated_gene', 'Ensembl_MGI', 'Ensembl_MGI_curated_gene'])
		#ret = self.alias.where(source: db).pluck(:alias).uniq
		ret = self.alias.where("SOURCE LIKE '%GN'").pluck(:alias).uniq
		# return ret.first if ret.size == 1
		ret
	end
	
	def ensembl_gene_id(db = "Ensembl")
		ret = self.alias.where(source: db).pluck(:alias).uniq
		# return ret.first if ret.size == 1
		ret
	end
	
	def self.find_by_alias(aliases)
		StringProtein.joins(:alias).where("string_protein_alias.alias" => aliases).uniq
	end
	
end

class StringProteinAliasName < ActiveRecord::Base
	self.table_name = "string_protein_alias"
	attr_accessible :stringdb_id, :ensembl_protein_id, :alias, :source, :taxon_id, :organism_id
	
	# has_and_belongs_to_many :string_proteins, join_table: :string_protein_links
	has_many :string_proteins, 
		primary_key: "stringdb_id", 
		foreign_key: "stringdb_id",
		readonly: true
	
end

class StringProteinLink < ActiveRecord::Base
	attr_accessible :stringdb1_id, :stringdb2_id, :neighborhood, :neighborhood_transferred, 
									:fusion, :cooccurence, :homology, :coexpression, :coexpression_transferred, 
									:experiments, :experiments_transferred, :database, :database_transferred, 
									:textmining, :textmining_transferred, :combined_score, 
									:taxon_id, :organism_id
	
	has_one :string_protein, class_name: "StringProtein", primary_key: "stringdb1_id", foreign_key: "stringdb_id", readonly: true
	has_many :variations, through: :string_protein, readonly: true
	has_many :variation_calls, through: :string_protein, readonly: true
	
	# has_many :vep, through: :string_protein
	# has_many :variation_calls, through: :string_protein
	
	has_one :source, class_name: "StringProtein", primary_key: "stringdb1_id", foreign_key: "stringdb_id", readonly: true
	has_one :sink,   class_name: "StringProtein", primary_key: "stringdb2_id", foreign_key: "stringdb_id", readonly: true
	
	def nodes
		[
			StringProtein.find(self.stringdb1_id),
			StringProtein.find(self.stringdb2_id)
		]
	end
	
end

class StringProteinAction < ActiveRecord::Base
	attr_accessible :stringdb1_id, :stringdb2_id, 
									:mode, :action, 
									#:sources, :transfered_sources, 
									:a_is_acting, :score,
									:taxon_id, :organism_id,
									:bind, :biocarta, :biocyc, :dip, :grid, :hprd, :intact, :kegg_pathways, :mint, :pdb, :pid, :reactome
	
	has_one :string_protein, class_name: "StringProtein", primary_key: "stringdb1_id", foreign_key: "stringdb_id", readonly: true
	
	has_one :source, class_name: "StringProtein", primary_key: "stringdb1_id", foreign_key: "stringdb_id", readonly: true
	has_one :sink,   class_name: "StringProtein", primary_key: "stringdb2_id", foreign_key: "stringdb_id", readonly: true
	
	def nodes
		[
			StringProtein.find(self.stringdb1_id),
			StringProtein.find(self.stringdb2_id)
		]
	end
	
end

class Stringdb < StringProtein # inhertitence is mostly used to have a link to a table name that can be checked... not really neccessary.
	def self.import(taxon_id, organism_id)
		datadir = File.join(Rails.root, "extras", "snupy_again", "aqua", "annotations", "stringdb", "data", taxon_id.to_s)
		raise "#{datadir} does not exist" unless Dir.exists?(datadir)
		required_files = YAML.load_file(File.join(Rails.root, "extras", "snupy_again", "aqua", "annotations", "stringdb", "stringdb.yaml"))
		required_files = required_files[taxon_id]
		required_files.keys.each do |name|
			required_files[name]["file"] = File.join(datadir, required_files[name]["file"])
		end
		
		if !required_files.all?{|name, conf| File.exist?(conf["file"])} then
			raise "Files are missing. Please make sure #{required_files.map{|n, conf| File.basename(conf["file"])}.join(" and ")} are downloaded to #{datadir}. The protein.links.full and action.detailed files will be detected in case you requested a license"
		end
		
		# Import StringProteins from alias
		import_proteins(required_files, taxon_id, organism_id)
		
		# Import of aliases..
		import_protein_alias(required_files, taxon_id, organism_id)
		
		# import links
		import_protein_links(required_files, taxon_id, organism_id)
		
		# import actions for links...
		import_protein_actions(required_files, taxon_id, organism_id)
	end
	
private
	
	def self.import_proteins(required_files, taxon_id, organism_id)
		if StringProtein.where(taxon_id: taxon_id).count == 0 
			puts "importing protein ids..."
			buffer = []
			stringids = Hash.new(false)
			read_file(required_files["alias"]){|cols|
				next if stringids["#{taxon_id}.#{cols[1]}"]
				stringids["#{taxon_id}.#{cols[1]}"] = true
				buffer << StringProtein.new({
					stringdb_id: "#{taxon_id}.#{cols[1]}",
					ensembl_protein_id: cols[1],
					taxon_id: taxon_id,
					organism_id: organism_id
				})
				if buffer.size > 1000 then
					SnupyAgain::DatabaseUtils.mass_insert(buffer)
					buffer = []
				end
			}
			SnupyAgain::DatabaseUtils.mass_insert(buffer) if buffer.size > 0
		else
			puts "Skipping import of protein ids..."
		end
	end
	
	def self.import_protein_alias(required_files, taxon_id, organism_id)
		if StringProteinAliasName.where(taxon_id: taxon_id).count == 0
			puts "importing protein aliases..." 
			buffer = []
			read_file(required_files["alias"]){|cols|
				cols[3].split(" ").each do |source|
					buffer << StringProteinAliasName.new({
						stringdb_id: "#{taxon_id}.#{cols[1]}",
						ensembl_protein_id: cols[1],
						alias: cols[2],
						source: source,
						taxon_id: taxon_id,
						organism_id: organism_id
					})
				end
				if buffer.size > 1000 then
					SnupyAgain::DatabaseUtils.mass_insert(buffer)
					buffer = []
				end
			}
			SnupyAgain::DatabaseUtils.mass_insert(buffer) if buffer.size > 0
		else
			puts "Skipping import of protein aliases..."
		end
	end
	
	def self.import_protein_links(required_files, taxon_id, organism_id)
		if StringProteinLink.where(taxon_id: taxon_id).count == 0 
			puts "importing protein links..."
			buffer = []
			header = []
			read_file(required_files["links"], " "){|cols|
				if header.size == 0 then
					header = cols
					header[header.index("protein1")] = "stringdb1_id"
					header[header.index("protein2")] = "stringdb2_id"
					next
				end
				rec = Hash[header.each_with_index.map{|a, idx| [a, cols[idx]]}]
				rec["taxon_id"] = taxon_id
				rec["organism_id"] = organism_id
				buffer << StringProteinLink.new(rec)
				if buffer.size > 1000 then
					SnupyAgain::DatabaseUtils.mass_insert(buffer)
					buffer = []
				end
			}
			SnupyAgain::DatabaseUtils.mass_insert(buffer) if buffer.size > 0
		else
			puts "Skipping import of protein links..."
		end
	end
	
	def self.import_protein_actions(required_files, taxon_id, organism_id)
		if StringProteinAction.where(taxon_id: taxon_id).count == 0 
			puts "importing protein link actions..."
			buffer = []
			header = []
			cnt = 0
			read_file(required_files["actions"], "\t"){|cols|
				if header.size == 0 then
					header = cols
					header[header.index("item_id_a")] = "stringdb1_id"
					header[header.index("item_id_b")] = "stringdb2_id"
					next
				end
				rec = Hash[header.each_with_index.map{|a, idx| [a, cols[idx]]}]
				rec["taxon_id"] = taxon_id
				rec["organism_id"] = organism_id
				print "#{cnt} \r" if cnt % 1000 == 0
				cnt = cnt + 1
				[:bind, :biocarta, :biocyc, :dip, :grid, :hprd, :intact, :kegg_pathways, :mint, :pdb, :pid, :reactome].each do |source_name|
					rec[source_name] = 0
					rec[source_name] += 1 if rec["transferred_sources"].to_s.upcase.index(source_name.to_s.upcase)
					rec[source_name] += 2 if rec["sources"].to_s.upcase.index(source_name.to_s.upcase)
					rec[source_name] = nil if rec[source_name] == 0
				end
				# now get the link and clean up the hash so we can use it for an update
				rec.delete("transferred_sources")
				rec.delete("sources")
				buffer << StringProteinAction.new(rec)
				if buffer.size > 1000 then
					SnupyAgain::DatabaseUtils.mass_insert(buffer)
					buffer = []
				end
			}
			SnupyAgain::DatabaseUtils.mass_insert(buffer) if buffer.size > 0
		else
			puts "cant import protein actions, already imported..."
		end
	end
	
	def self.read_file(conf, sep = "\t", &block)
		begin
			if !conf["zipped"]
				fin = File.new(conf["file"], "r")
			else
				fin = File.new(conf["file"], "rb")
				fin = Zlib::GzipReader.new(fin) if conf["zipped"]
			end
		rescue Errno::ENOENT
			raise "File #{conf['file']} not found. Please make sure you download String 9.1 from string-db.org and place it in the given location."
		end
		ret = []
		fin.each_line do |l|
			next if l[0] == "#"
			l.strip!
			# cols = l.encode!('UTF-8', 'UTF-8', invalid: :replace, undef: :replace, replace: '').split(sep)#l.force_encoding("utf-8").split("\t")
			cols = encode_string(l).split(sep)#l.force_encoding("utf-8").split("\t")
			if block_given?
				yield cols
			else
				ret << cols
			end
		end
		fin.close
		return ret unless block_given?
		return nil
	end
	
	def self.encode_string(str)
		if String.method_defined?(:encode)
			begin
				ret = str.encode('UTF-16', 'UTF-8', :invalid => :replace, :replace => '')
				ret = ret.encode('UTF-8', 'UTF-16')
			rescue => e
				ret = str.force_encoding("UTF-8")
			end
		else
			ic = Iconv.new('UTF-8', 'UTF-8//IGNORE')
			ret = ic.iconv(file_contents)
		end
		ret
	end
	
end


