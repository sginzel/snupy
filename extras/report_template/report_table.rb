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
	
	def table
		@table
	end
	
	def header
		@table.first
	end
	
	def rows(include_header = false)
		if include_header then
			start = 0
		else
			start = 1
		end
		@table[start...@table.size]
	end
	
	def add_row(fields, style = nil)
		@table << ReportTableRow.new(fields, header)
		if style
			add_row_style(@table.size-1, style)
		end
	end
	
	def add_row_style(rowno, style)
		mystyle = ActiveSupport::HashWithIndifferentAccess.new
		[:background, :color, :bold, :italic, :size].each do |x|
			if style[x]
				if style[x].duplicable?
					mystyle[x] = style[x].dup
				else
					mystyle[x] = style[x]
				end
			end
		end
		row_styles.insert(rowno, mystyle)
	end
	
	def add_cell_style(rownos = nil, colnos = nil, style = {})
		rownos = (0...@table.size).to_a if rownos.nil?
		colnos = (0...header.columns.size).to_a if colnos.nil?
		rownos = [rownos] unless rownos.is_a?(Array)
		colnos = [colnos] unless colnos.is_a?(Array)
		mystyle = ActiveSupport::HashWithIndifferentAccess.new
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
	
	def each_row(include_header = false, &block)
		if (block_given?)
			rows(include_header).each do |row|
				yield row
			end
		else
			rows(include_header)
		end
	end
	
	def each_column(include_header = true, &block)
		ret = []
		header.each do |colname|
			colvals = []
			each_row(include_header) do |row|
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
	
	def add_to_document(docx, &block)
		if (block_given?)
			docx.table [[to_caracal(&block)]]
		else
			docx.table [[to_caracal()]]
		end
		docx
	end
	
	def render_docx(docx, &block)
		if (docx.is_a?(String)) then
			docx = generate_docx(docx)
		end
		add_to_document(docx, &block)
	end
	
	def to_caracal(&block)
		data = to_a.map{|rw|
			rw.columns.map{|cl|
				if cl.is_a?(ReportTable) then
					cl.to_caracal()
				elsif cl.is_a?(Caracal::Core::Models::BaseModel) then
					if cl.is_a?(Caracal::Core::Models::TableCellModel) then
						cl
					else
						cellmodel = Caracal::Core::Models::TableCellModel.new
						cellmodel.contents << cl
						cellmodel
					end
				elsif cl.is_a?(ReportTableCell) then
					cl.content
				elsif cl.is_a?(Array) then
					cellmodel = Caracal::Core::Models::TableCellModel.new do |tcm|
						cl.each do |element|
							tcm.p element.to_s
						end
					end
					cellmodel
				else
					Caracal::Core::Models::TableCellModel.new do |cellmodel|
						cellmodel.p cl.to_s
					end
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
				if block_given?
					t.instance_eval(&block)
				end
			end
		end
	end
	
	def to_a
		[header, rows].flatten
	end
	
	def to_s
		txt = []
		colwidth = each_column(true).map{|colvals| colvals.map{|x| x || ""}.map(&:size).max + 3}
		hdr = header.to_s(colwidth)
		txt << "─" * hdr.size
		txt << hdr
		txt << "─" * hdr.size
		rows(false).each do |row|
			txt << row.to_s(colwidth)
		end
		txt << "─" * hdr.size
		txt.join("\n")
	end
	
	def generate_docx(file = "tmp/#{Time.now.to_i.to_s(36).upcase}.docx")
		Caracal::Document.new(file)
	end
end

class ReportTableRow
	
	def initialize(fields, header)
		cnt = 0
		#@columns = {}.with_indifferent_access
		@columns = ActiveSupport::HashWithIndifferentAccess.new
		header = header.columns if header.is_a?(ReportTableRow)
		if fields.is_a?(Array) then
			fields = Hash[header.each_with_index.map{|colname, i| [colname, fields[i]] }]
		else
			fields = ActiveSupport::HashWithIndifferentAccess.new fields
			myfields = ActiveSupport::HashWithIndifferentAccess.new
			header.each do |colname|
				myfields[colname] = fields[colname]
			end
			fields = myfields
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
	
	def to_s(colwidth = nil)
		colwidth = @columns.map{|colname, cell| [colname.size, (cell || "").size].max + 3} unless colwidth
		columns.each_with_index.map{|cellval, i|
			sprintf(" %s ", cellval.to_s.ljust(colwidth[i], " "))
		}.join("│")
	end

end

class ReportTableCell
	def initialize(opts = {})
		@opts = opts
	end
	
	def content
		Caracal::Core::Models::TableCellModel.new do |tbc|
			tbc.p opts.to_s
		end
	end
end

class ReportTableImage <  ReportTableCell
	def content
		defaults = {
			width: 100,
			height: 100
		}
		Caracal::Core::Models::TableCellModel.new do |tbc|
			tbc.img defaults.merge(@opts)#url: "https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png", width: 300, height: 300
		end
	end
end

# content should return a proc that is evaluated
# This would allow us to have arrays of table cells
class ReportTableLink < ReportTableCell
	
	def initialize(url, label, opts = {})
		@url = url
		@label = label
		@opts = opts
	end
	
	def content
		defaults = {
			internal:        false,             # sets whether or not the link references an external url. defaults to false.
			font:            'Courier New',     # sets the font name to use. defaults to nil.
			color:           '0000ff',          # sets the color of the text. defaults to 1155cc.
			size:            14,                # sets the font size. units in half-points. defaults to nil.
			bold:            false,             # sets whether or not the text will be bold. defaults to false.
			italic:          false,             # sets whether or not the text will be italic. defaults to false.
			underline:       true,              # sets whether or not the text will be underlined. defaults to true.
			bgcolor:         'cccccc',          # sets the background color.
			highlight_color: 'yellow'          # sets the highlight color. only accepts OOXML enumerations. see http://www.datypic.com/sc/ooxml/t-w_ST_HighlightColor.html.
		}
		Caracal::Core::Models::TableCellModel.new do |tbc|
			tbc.link @label, @url, defaults.merge(@opts)
		end
	end
end