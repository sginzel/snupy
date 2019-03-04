# This class is used to create tables for docx files that are used as part of the report templates
#
class ReportTable
	
	attr_accessor :background_color, :font_color, :header_background_color, :header_font_color,
	              :row_styles, :cell_styles, :table_opts
	
	def initialize(header, table_opts = nil)
		@table                      = [ReportTableRow.new(header, header)]
		@background_color           = ["ffffff", "d3d3d3"]
		@font_color                 = ["000000"]
		@header_background_color    = "4682B4"
		@header_font_color          = "ffffff"
		@row_styles                 = [{background: @header_background_color, color: @header_font_color}]
		@cell_styles                 = []
		@table_opts                 = table_opts
	end
	
	def header
		@table.first
	end
	
	def rows
		@table[1...@table.size]
	end
	
	def add_row(fields, style = nil)
		@table << ReportTableRow.new(fields, header)
		if style
			add_row_style(@table.size-1, style)
		end
	end
	
	def add_row_style(rowno, style)
		mystyle = {}.with_indifferent_access
		[:background, :color, :bold, :italic, :size].each do |x|
			mystyle[x] = style[x].dup unless style[x].nil?
		end
		row_styles.insert(rowno, mystyle)
	end
	
	def add_cell_style(rownos = nil, colnos = nil, style = {})
		rownos = (0...@table.size).to_a if rownos.nil?
		colnos = (0...header.columns.size).to_a if colnos.nil?
		rownos = [rownos] unless rownos.is_a?(Array)
		colnos = [colnos] unless colnos.is_a?(Array)
		mystyle = {}.with_indifferent_access
		[:background, :color, :bold, :italic, :rowspan, :colspan, :size].each do |x|
			if style[x]
				mystyle[x] = style[x]
				mystyle[x] = mystyle[x].dup unless mystyle[x].is_a?(Fixnum)
			end
		end
		rownos.each do |rowno|
			colnos.each do |colno|
				cell_styles[rowno] ||= []
				cell_styles[rowno].insert(colno, mystyle)
			end
		end
	end
	
	def add_column(colname, default = nil)
		@table.each_row do |row|
			row.add_column(colname, default)
		end
	end
	
	def each_row(&block)
		if (block_given?)
			rows.each do |rowid|
				yield @table[rowid]
			end
		else
			rows
		end
	end
	
	def each_column(&block)
		ret = []
		header.each do |colname|
			colvals = []
			each_row do |row|
				colvals << row[colname]
			end
			if (block_given?)
				yield colvals
			else
				ret << colvals
			end
		end
		return nil if block_given?
		ret
	end
	
	def render_docx(docx, &block)
		if (docx.is_a?(String)) then
			docx = generate_docx(docx)
		end
		if (block_given?)
			docx.table [[to_caracal(&block)]]
		else
			docx.table [[to_caracal()]]
		end
	end
	
	def to_caracal(&block)
		data = to_a.map{|rw|
			rw.columns.map{|cl|
				if cl.is_a?(ReportTable) then
					cl.to_caracal
				elsif cl.is_a?(Caracal::Core::Models::BaseModel) then
					cellmodel = Caracal::Core::Models::TableCellModel.new
					cellmodel.contents << cl
					cellmodel
				else
					Caracal::Core::Models::TableCellModel.new do |cellmodel|
						cellmodel.p cl.to_s
					end
					#cl.to_s
				end
			}
		}
		Caracal::Core::Models::TableCellModel.new do |tcm|
			tcm.table data, @table_opts do |t|
				rows.each_with_index do |r, idx|
					idx = idx + 1
					bgcol = @background_color[idx % @background_color.size]
					fcol  = @font_color[idx % @font_color.size]
					t.cell_style t.rows[idx],  bold: false, background: bgcol, color: fcol
				end
				@row_styles.each_with_index do |style, i|
					next unless style
					t.cell_style t.rows[i], style
				end
				@cell_styles.each_with_index do |colno_to_style, rowno|
					next unless colno_to_style
					colno_to_style.each_with_index do |style, colno|
						next unless style
						next unless t.rows[rowno]
						t.cell_style t.rows[rowno][colno], style
						#t.cell_style t.cells[i], style
					end
					
				end
				t.instance_eval(&block)
			end
		end
	end
	
	def to_a
		[header, rows].flatten
	end
	
	def generate_docx(file = "tmp/#{Time.now.to_i.to_s(36).upcase}.docx")
		Caracal::Document.new(file)
	end
end

class ReportTableRow
	
	def initialize(fields, header)
		cnt = 0
		@columns = {}.with_indifferent_access
		header = header.columns if header.is_a?(ReportTableRow)
		if fields.is_a?(Array) then
			fields = Hash[header.each_with_index.map{|colname, i| [colname, fields[i]] }]
		else
			fields = fields.with_indifferent_access
			header.each do |colname|
				fields[colname] = nil if fields[colname].nil?
			end
		end
		header.each do |colname|
			@columns[colname] = fields[colname]
		end
		self
	end
	
	def add_column(colname, default = nil)
		if !include?(colname) then
			@columns[colname] = default
		end
		self
	end
	
	def each(&block)
		if (block_given?)
			columns.each do |cell|
				yield cell
			end
		else
			columns
		end
	end
	
	def columns(colname = nil)
		if colname then
			@columns[colname]
		else
			@columns.values
		end
	end
	
	def [](colname)
		columns(colname)
	end
	
	def colnames
		@columns.keys
	end
	
	def include?(colname)
		colnames.include?(colname)
	end
	
end