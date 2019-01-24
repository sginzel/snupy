class GenericRegionList < GenericList
	
	def create_item(record, header, cols, idxs)
		chr = cols[idxs[0]]
		start = cols[idxs[1]]
		stop = cols[(idxs[2] || idxs[1])]
		record["region"] = "#{chr}:#{start}-#{stop}"
		idxs.each{|idx| record.delete(header[idx]) }
		GenericListItem.new(value: record)
	end
	
	# require "csv"
	def read_data_old(opts = {})
		opts = opts.reverse_merge({file: nil, idx: 0, sep: "\t", has_header: false})
		data = opts[:data]
		file = opts[:file]
		idxs = opts[:idx].split(",").map(&:to_i)
		sep = opts[:sep]
		has_header = opts[:header]
		if !file.nil? then
			content = file.read
			content.gsub!(/\r\n?/, "\n")
			items = []
			items2add = []
			lineno = 0
			header = []
		elsif data.to_s != ""
			content = data
		else			
			self.errors[:base] = "No data found"
			return false
		end
		content.each_line do |line|
			line = line.strip
			lineno = lineno + 1
			# cols = line.split(sep)
			cols = CSV.parse_line(line, {col_sep: sep})
			if lineno == 1 then
				if has_header then
					header = cols
					next
				else
					header = cols.each_with_index.map{|c,i| "Column#{i}"}
				end
			end
			# d "item: " + cols[idx].to_s
			val = Hash[cols.each_with_index.map{|c,i| [header[i], cols[i]]}]
			chr = cols[idxs[0]]
			start = cols[idxs[1]]
			stop = cols[(idxs[2] || idxs[1])]
			val["region"] = "#{chr}:#{start}-#{stop}"
			idxs.each{|idx| val.delete(header[idx]) }
			items2add << GenericListItem.new(value: val)
		end
		self.items = items2add
		true
	end
end