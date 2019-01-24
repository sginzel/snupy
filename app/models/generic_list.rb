# == Description
# A GenericList enables us to store lists as subclassed of this class. 
# Currently available are: GenericGeneList and GenericRegionList
# Each list hast to be inherited and should be stored in app/models/generic_list 
# so it can be loaded automatically. 
# Each inherited class need to implement a create_item method that generates the item from a user entry.
# The user input is given as an Array that is created from a CSV input. 
class GenericList < ActiveRecord::Base
	require "csv"
	AVAILABLE_TYPES = %w(GenericGeneList GenericRegionList)
	
	has_and_belongs_to_many :users, join_table: :generic_list_has_users
	has_many :affiliations, through: :users
	has_many :institutions, through: :affiliations
	has_many :generic_list_items, inverse_of: :generic_list, dependent: :destroy
  attr_accessible :description, :name, :title, :type
  
  def read_data(opts)
  	# raise NotImplementedError.new("read_data is not implemented for this class")
  	opts = opts.reverse_merge({data: nil, file: nil, idx: 0, sep: "\t", has_header: false})
  	data = opts[:data]
		file = opts[:file]
		idxs = opts[:idx].split(",").map(&:to_i)
		sep = opts[:sep]
		has_header = opts[:header]
		if !file.nil? then
			# content = file.read
			file = file
		elsif data.to_s != "" then
			# fin = File.new(oldsmpl["file"], "r")
			file = File.new("/tmp/#{data.hash}", "w+")
			file.write(data.to_s)
			file.seek(0)
			# content = data.to_s
		else
			self.errors[:base] << "Missing data."
			return false
		end
		# content.gsub!(/\r\n?/, "\n")
		items = []
		items2add = []
		lineno = 0
		header = []
		begin
			CSV.read(file, 
							 col_sep: sep, 
							 quote_char: '"', 
							 headers: has_header, 
							 return_headers: true,
							 skip_blanks: true,
							 force_quotes: false,
							 encoding: "UTF-8")
			.each do |cols|
			 	if lineno == 0 then
			 		if has_header
			 			header = cols.headers
			 			lineno = lineno + 1
				 		next
			 		else
			 			header = (0...(cols.size)).to_a.map(&:to_s)
			 		end
			 		lineno = lineno + 1
			 	end
			 	record = Hash[header.each_with_index.map{|c,i| [header[i], cols[i].to_s.gsub("\n", " ").force_encoding("utf-8")]}]
				items2add << create_item(record, header, cols, idxs)
				lineno = lineno + 1
			end
		rescue => e
			self.errors[:base] << "[LINE ##{lineno+1}] " + e.message
			return false
		end
			
		if items2add.size > 0 then
			self.transaction do 
				self.items = [] if self.items.size > 0
				self.items = items2add
			end
		end
		if data.to_s != "" then
			file.close
			File.unlink(file.path)
		end
		true
  end
  
  def create_item(record, header, cols, idxs)
  	raise NotImplementedError.new("create_item is not implemented for this class")
  end
  
  def items()
	  self.generic_list_items
  end
  
  def items=(items)
  	self.generic_list_items=items
  end

protected
	def self.available_lists()
		## load all available classes
		SnupyAgain::Application.config.autoload_paths.each do |path|
			next unless path =~ /.*generic_list.*/
			Dir.new(path).each do |file|
				next unless file =~ /.rb$/
				classtoload = file.gsub(/.rb$/, "").split("_").map(&:capitalize).join("")
				tmp = Kernel.const_get(classtoload.to_sym)
			end
		end
		GenericList.descendants
	end

  
end
