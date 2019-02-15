require('open-uri')
class Digenic < ActiveRecord::Base
	self.table_name = 'digenics'
	
	has_many :vep, class_name: "Vep::Ensembl", primary_key: "gene_id", foreign_key: "gene_symbol", readonly: true
	has_many :variations, through: :vep, readonly: true
	has_many :variation_calls, through: :variations, readonly: true
	has_many :samples, through: :variation_calls, readonly: true
	
	attr_accessible :gene_id, :gene_partner_id, :score,
					:disease_name, :association_description,
					:evidence_record, :source_db, :source_id, :source_file,
					:organism_id
	
	def self.import(config = self.configuration, names = nil)
		if (names.nil?)
			names = config.keys
		else
			names = [names] unless names.is_a?(Array)
		end
		names.map{|n|
			self.import_config(n, config[n])
		}
	end
	
	def self.configuration
		YAML.load_file(File.join(Rails.root, 'extras', 'snupy_again', 'aqua', 'annotations', 'digenic', 'digenic.yaml'))
	end
	
private
	def self.import_config(name, conf)
		defaults = {
			'file' => Rails.root.join("tmp", "dida.csv").to_s,
			'type' => 'local', # may be remote or local
			'zipped' => false, # true or false
			'header' => true, # has header
			'format' => :tsv, # :tsv only - extendable later
			'sep' => "\t", # septerator
			'quote' => '"', # quote character
			'gene_id_index' => 0, # id of gene_ID 0-based
			'gene_partner_id_index' => 1, # id of partner gene_ID 0-based
			'score_index' => nil, # if NULL will default to 1
			'disease_name_index' => 2, # disease name index
			'association_description_index' => 3, # gene interaction description id
			'source_db_index' => nil, # if NULL wil be set to name
			'source_id_index' => nil # ID from source database
		}
		# file, organism_id, md5sum need to be set
		required = %w(file organism_id md5sum)
		field_to_attribute = {
			'gene_id_index' => :gene_id,
			'gene_partner_id_index' => :gene_partner_id,
			'score_index' => :score,
			'disease_name_index' => :disease_name,
			'association_description_index' => :association_description,
			'source_db_index' => :source_db,
			'source_id_index' => :source_id,
			
		}
		conf = defaults.merge(conf)
		raise 'Configuration of digenic associations need to carry organism_id, file and md5sum' if required.any?{|x| conf[x].nil?}

		pp conf
		if !File.exists?(conf['file']) then
			download(conf['url'], conf['file'])
		end

		header = nil
		if !conf['header'] then
			header = []
		end
		
		if Digest::MD5.file(conf['file']) != conf['md5sum'] then
			raise 'given and actual md5sum do not match'
		end
		
		Digenic.transaction do
			self.read_file(conf) do |cols|
				if header.nil? then
					header = cols
					next
				end
				if (header.size == 0)
					header = (0...cols.size).to_a
				end
				record = Hash[header.each_with_index.map{|h, i|
					[h, cols[i]]
				}]
				attrs = Hash[field_to_attribute.map{|from, to|
					next if conf[from].nil?
					[to, cols[conf[from]]]
				}]
				## set some defaults
				attrs['source_file'] = conf['file']
				attrs['organism_id'] = conf['organism_id']
				attrs['source_db'] = name if attrs['source_db'].nil?
				attrs['evidence_record'] = record.to_yaml
				
				Digenic.create(attrs)
				
			end
		end
	end

	def self.read_file(conf, &block)
		begin
			if !conf['zipped']
				if conf['type'] == 'remote'
					fin = OpenURI.open_uri(conf['file'])
				else
					fin = File.new(conf['file'], 'r')
				end
			else
				if conf['type'] == 'remove'
					fin = OpenURI.open_uri(conf['file'])
					if conf['zipped']
						fin.binmode
						fin = Zlib::GzipReader.new(fin)
					end
				else
					fin = StringIO.new
					Zip::InputStream.open(conf['file']) do |zis|
						fin = zis.get_next_entry.get_input_stream
					end
					#fin = File.new(conf['file'], 'rb')
					#fin = Zlib::GzipReader.new(fin) if conf['zipped']
				end
			end
		rescue Errno::ENOENT
			raise "File #{conf['file']} not found. Please make sure you download String 9.1 from string-db.org and place it in the given location."
		end
		ret = []
		fin.each_line do |l|
			next if l[0] == '#'
			l.strip!
			l = encode_string(l)#.split(sep)#l.force_encoding("utf-8").split("\t")
			cols = CSV.parse_line(l, col_sep: conf['sep'], quote_char: conf['quote'])
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

	def self.download(url, fname)
		if (url[0..3] == "file") then
			if File.exist?(url[7..-1])
				return url[7..-1]
			else
				raise "local file #{url} does not exist."
			end
		end
		print sprintf("Downloading %s -> %s...".blue, File.basename(url), fname)
		if !(File.exists? fname) then
			bytes = IO.copy_stream(open(url), fname)
			print sprintf("DONE %d bytes\n".blue, bytes)
		else
			print sprintf("EXISTS %d bytes\n".green, bytes)
		end
		fname
	end

end
