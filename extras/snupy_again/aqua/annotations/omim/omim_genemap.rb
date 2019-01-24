class OmimGenemap < ActiveRecord::Base
	@@CONFIG          = YAML.load_file(File.join(Aqua.annotationdir ,"omim", "omim_config.yaml"))[Rails.env]
	@@GENEMAPTABLE     = "omim_genemap#{@@CONFIG["version"].to_s.gsub(".", "_")}s".to_sym # there is a pending s to be confirm with RAILS pluralized table form
	self.table_name = @@GENEMAPTABLE
	
	# list all attributes here to mass-assign them
	attr_accessible :phenotype,
	                :phenotype_raw,
	                :gene_name,
	                :symbol,
	                :entrezid,
	                :ensembl_gene_id,
	                :symbol_alias,
	                :mgi_id,
	                :mgi_symbol,
	                :comments,
	                :gene_mim,
	                :phenotype_mim,
	                :is_nondisease,
	                :is_susceptible,
	                :is_provisional,
	                :map_wildtype,
	                :map_phenotype,
	                :map_molecular_known,
	                :map_chr_deldup,
	                :link_autosomal,
	                :link_x,
	                :link_y,
	                :link_mitochondrial,
	                :is_autosomal_recessive,
	                :is_autosomal_dominant,
	                :is_multifactorial,
	                :is_isolated_cases,
	                :is_digenic_recessive,
					:is_mitochondrial,
					:is_somatic_mutation,
					:is_somatic_mosaicism,
					:is_xlinked,
					:is_ylinked,
					:is_dominant,
					:is_recessive
	
	                          # optional method in case you want to do inheritance
	def self.aqua_table_alias
		self.table_name
	end
	
	def self.import_genemap2(filepath)
		header = nil
		buffer = []
		cnt = 0
		File.open(filepath, 'r').each_line do |line|
			cols = line.strip.split("\t")
			if cols[0][0] == "#" && cols.size == 1 then
				next
			elsif cols[0][0] == "#" && header.nil?
				header = cols.map{|x| x.gsub(" ", "")}.map(&:underscore)
				header[0].gsub("# ", "")
				next
			end
			raise "no header found" if header.nil?
			record = Hash[header.each_with_index.map{|h,i| [h, cols[i]]}]
			record["phenotypes"].to_s.split(";").each do |phenotype_raw|
				next if phenotype_raw.to_s == ""
				phenotype_raw.strip!
				genemap_template = parse_phenotype(phenotype_raw)
#				puts "  #{phenotype_raw} => #{genemap_template[:phenotype]} / #{genemap_template[:phenotype_mim]}".green
				genemap_template[:gene_name] = record["gene_name"]
				genemap_template[:gene_mim] = record["mim_number"]
				genemap_template[:symbol] = record["approved_symbol"]
				genemap_template[:comments] = record["comments"]
				genemap_template[:entrezid] = record["entrez_gene_id"]
				genemap_template[:ensembl_gene_id] = record["ensembl_gene_id"]
				genemap_template[:mgi_id] = record["mouse_gene_symbol/id"].to_s.split("(")[1].to_s.gsub(")", "")
				genemap_template[:mgi_symbol] = record["mouse_gene_symbol/id"].to_s.split(" ")[0].to_s
				gene_symbols = record["gene_symbols"].to_s.split(",").map(&:strip)
				gene_symbols = [nil] if gene_symbols.size == 0
				gene_symbols.each do |symbol_alias|
					genemap_attr = genemap_template.dup
					genemap_attr[:symbol_alias] = symbol_alias
					genemap_attr[:symbol] = symbol_alias if genemap_attr[:symbol].to_s == ""
					mgiids = genemap_attr[:mgi_id].split(",")
					mgiids = [nil] if mgiids.size == 0
					mgiids.each_with_index do |mgiid, mgiidx|
						genemap_attr[:mgi_id] = mgiid
						genemap_attr[:mgi_symbol] = genemap_attr[:mgi_symbol].to_s.split(",")[mgiidx]
						buffer << OmimGenemap.new(genemap_attr.dup)
						if buffer.size >= 5000 then
							cnt += buffer.size
							print("Writing #{buffer.size} genemap entries (#{cnt} total)                    \r")
							SnupyAgain::DatabaseUtils.mass_insert(buffer)
							buffer = []
						end
					end
				end
			end
		end
		if buffer.size > 0 then
			cnt += buffer.size
			print("Writing #{buffer.size} genemap entries (#{cnt} total)                    \r")
			SnupyAgain::DatabaseUtils.mass_insert(buffer)
		end
		print("\nDONE inserting #{cnt} genemap associations")
	end
	
	def self.parse_phenotype(pstring)
		# {Alkaline phosphatase, plasma level of, QTL 2}, 612367 (2)
		# {Dyslexia, susceptibility to, 8}, 608995 (2), Autosomal dominant, Multifactorial
		mimid, mapid = pstring.scan(/([123456][0-9]+) \(([1234])\)/).first
		mimid = mimid.to_s
		# scan(/.+ ([0-9]*) \(([1234])\)/).first
		if mimid != "" then
			phenotype, rest = pstring.scan(/(.*), [0-9]* \([1234]\)[, ]*(.*)/).first
		else
			phenotype, rest = pstring.scan(/(.*).*\([1234]\)[, ]*(.*)/).first
		end
		{
           :phenotype              => phenotype.gsub(/[\]\[{}?]/, "").strip.gsub(",", ";"),
           :phenotype_raw          => pstring,
           :gene_name              => nil,
           :symbol                 => nil,
           :entrezid               => nil,
           :ensembl_gene_id        => nil,
           :symbol_alias           => nil,
           :mgi_id                 => nil,
           :mgi_symbol             => nil,
           :comments               => nil,
           :gene_mim               => nil,
           :phenotype_mim          => mimid,
           :is_nondisease          => pstring[0] == "[",
           :is_susceptible         => pstring[0] == "{",
           :is_provisional         => pstring[0] == "?",
           :map_wildtype           => mapid == "1",
           :map_phenotype          => mapid == "2",
           :map_molecular_known    => mapid == "3",
           :map_chr_deldup         => mapid == "4",
           :link_autosomal         => mimid[0] == "1" || mimid[0] == "2" || mimid[0] == "6",
           :link_x                 => mimid[0] == "3",
           :link_y                 => mimid[0] == "4",
           :link_mitochondrial     => mimid[0] == "5",
           :is_autosomal_recessive => contains?(rest, "Autosomal recessive", "AR"),
           :is_autosomal_dominant  => contains?(rest, "Autosomal dominant", "AD"),
           :is_multifactorial      => contains?(rest, "Multifactorial"),
           :is_isolated_cases      => contains?(rest, "Isolated cases"),
           :is_digenic_recessive   => contains?(rest, "Digenic recessive"),
           :is_mitochondrial       => contains?(rest, "Mitochondrial"),
           :is_somatic_mutation    => contains?(rest, "Somatic mutation"),
           :is_somatic_mosaicism   => contains?(rest, "Somatic mosaicism"),
           :is_xlinked             => contains?(rest, "X-linked"),
           :is_ylinked             => contains?(rest, "Y-linked"),
           :is_dominant            => contains?(rest, "dominant"),
           :is_recessive           => contains?(rest, "recessive")
		}
	end
	
private
	def self.contains?(str, *args)
		return false if str.to_s == ""
		args.any?{|x|
			!str.to_s.index(x).nil?
		}
	end
	
end

# Inheritance example - uses source as type column
#class Vep::Ensembl < Vep
#	self.inheritance_column   = 'source'
#	self.store_full_sti_class = false # if we don't do this ActiveRecord assumes the value to be Vep::Ensembl instead of Ensembl
#
#	has_many :ref_seq, :class_name => "Vep::RefSeq",
#			 :foreign_key          => "variation_id", conditions: proc {"organism_id = #{self.organism_id}"}
#	def self.aqua_table_alias
#		"vep_ensembls"
#	end
#
#end