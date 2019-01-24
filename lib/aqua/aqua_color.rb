module AquaColor
	# If using RGB color space use balance_factor = 100
	def create_color_gradient(values = [0, 1], colors = [Color::RGB::Red.to_hsl, Color::RGB::Green.to_hsl], balance_factor = 1, use_hsl = true)
		points = {}
		raise "Values #{values.to_s} and colors #{colors.to_s} have to be the same length > 1" if (values.length != colors.length) or values.length < 1
		values.each_with_index{|v, i|
			points[v] = _get_colorval(colors[i], use_hsl)
		}
		gradient = Interpolate::Points.new(points)
		gradient.blend_with {|color, other, balance|
			# col = Color::HSL.from_fraction(color[0], color[1], color[2])
			# othrcol = Color::HSL.from_fraction(other[0], other[1], other[2])
			# col.mix_with(othrcol , balance * 100.0)
			color.mix_with(other , balance * balance_factor)
		}
		gradient
	end
	
	def create_log_color_gradient(values = [0, 1], colors = [Color::RGB::Red.to_hsl, Color::RGB::Green.to_hsl], balance_factor = 1, use_hsl = true)
		newvals = values.map{|v| 
			_log_val(v)
		}
		gradient = create_color_gradient(newvals, colors, balance_factor, use_hsl)
		#redefine at method
		def gradient.at(value) 
			newval = Aqua._log_val(value)
			super(newval)
		end
		
		def gradient.is_log?()
			true
		end
		
		gradient
	end
	
	def color_bool()
		{
			true: "palegreen",
			false: "salmon",
			True: "palegreen",
			False: "salmon",
			"true" => "palegreen",
			"false" => "salmon",
			"True" => "palegreen",
			"False" => "salmon",
			"TRUE" => "palegreen",
			"FALSE" => "salmon",
			"1" => "palegreen",
			"0" => "salmon",
			1 => "palegreen",
			0 => "salmon",
			"YES" => "palegreen",
			"NO" => "salmon",
			"yes" => "palegreen",
			"no" => "salmon",
			"Yes" => "palegreen",
			"No" => "salmon"
		}
	end
	
	def factor_color(str, shade = :light)
		if @_cbcols.nil? then
			@_cbcols = {
				set3: %w(#8dd3c7 #ffffb3 #bebada #fb8072 #80b1d3 #fdb462 #b3de69 #fccde5 #d9d9d9 #bc80bd #ccebc5 #ffed6f), #12-class Set3
				paired: %w(#a6cee3 #1f78b4 #b2df8a #33a02c #fb9a99 #e31a1c #fdbf6f #ff7f00 #cab2d6 #6a3d9a #ffff99 #b15928), #12-class Paired
				pastel: %w(#fbb4ae #b3cde3 #ccebc5 #decbe4 #fed9a6 #ffffcc #e5d8bd #fddaec #f2f2f2), # 9-class Pastel1
				light1: %w(#ffb2b0 #02c6df #fba28b #55b5f2 #bdb66b #c7beff #b1e8a6 #ffc7cd #82efce #cba575 #99fffc #fff0b0 #82b3c0 #b6ab87 #83b6a2), # generated using http://tools.medialab.sciences-po.fr/iwanthue/
				light2: %w(#c2ffa4 #f181f3 #00de3f #ff94bd #d4d900 #44c9ff #fff882 #2dbcd0 #ea9955 #51c174 #ffc0b1 #a2b54a #fff0c6 #d1a27c #e0ffc9),
				light3: %w(#ff899a #ffc1b9 #d2a387 #ffc698 #ffee71 #9eb74f #d8ffb5 #59f0a0 #1ac586 #56ffc8 #44c0a2 #2fffe0 #8fd2c8 #01e3dc #0cddff #77deff #0fbce7 #91afdb #e18efa #ffb5e9),
				light4: %w(#ffc8b7 #41d7e1 #e5bf83 #edccff #a1eab1 #f6b4b0 #96ffdc #e5b8c9 #f0ffc8 #8fcde8 #ffecaf #ffe0fd #cbfffe #e1bbc2 #ffe7cb #c2c3d7 #dabfaf #d5becd),
				light:  %w(#ffc4b4 #fedad0 #ffcda3 #eccc93 #e4cea3 #fff8ca #f9f4b3 #faffc4 #bcebb5 #b4d9bf #b9fbcf #a2ffec #b3d5e9 #a0d7ff),
				blue: %w(#7a98b5 #899ca4 #27b2d1 #50b8ce #91b3bc #85b3dc #5bd2f6 #7bcfff #a2ccf4 #9ae7ff),
				red: %w(#bf836c #ac8989 #cc7c72 #a48d80 #be8696 #e48ba6 #c2a6ad #ffaca7 #fbb589 #e7c1ac),
				green: %w(#779b74 #8bae6c #a8a981 #6fc69b #8acbb7 #d2d3a1 #c3dad2 #b0e8aa #c0ffd5 #fbffe2)
			}
			@_cbcols.default = ["black", "white"]
		end
		idx = get_factor_id(str)
		@_cbcols[shade][idx % @_cbcols[shade].size]
	end
	
	def color_factor(factors, shade = :light)
		ret = {}
		factors = [factors] unless factors.is_a?(Array)
		
		factors.uniq.sort.each_with_index do |factor, i|
			#idx = factor.to_s.hash.abs % cbcols[shade].size # unfortunatly the hash doesnt stay the same when a new ruby instance is created
			ret[factor] = factor_color(factor, shade)
			# ret[factor] = cbcols[shade][i % cbcols[shade].size]
		end
		ret
	end
	
	def get_color(value, gradient)
		gradiant.at(value).html
	end
	
	def _log_val(v)
		(v.to_f == 0.0)?0.0001:Math.log(v.to_f.abs)
	end
private 
	
	def get_factor_id(str)
		@_md5 = Digest::MD5.new if @_md5.nil?
		@_md5.reset
		@_md5.update str.to_s
		@_md5.to_s.to_i(16).abs
	end
	
	def _get_colorval(colval, use_hsl = true)
		ret = colval
		if colval.is_a?(String)
			if colval[0] != "#" then
				ret = Color::RGB.by_name(colval)
			else
				ret = Color::RGB.by_hex(colval)
			end
			if use_hsl then
				ret = ret.to_hsl
			end
		end
		ret
	end
end
