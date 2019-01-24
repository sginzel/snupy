# This class is used to store the results of an AQuA query process.
# Because we are storing the cache data in JSON format it is pretty inefficient to 
# store an array of Integers as every integer is represented as a string and every 
# digit encoded as one character. 
#
#
# bigdata = []
# 10000.times do |i|
#   bigdata << i * rand(10000000)
# end
# puts Marshal.dump(bigdata).size
# puts "Compressed: #{Zlib::Deflate.deflate(Marshal.dump(bigdata))).size}"
# puts Marshal.dump(bigdata.map(&:to_s)).size
# puts "Compressed: #{Zlib::Deflate.deflate(Marshal.dump(bigdata.map(&:to_s))).size}"
# 
# bigdata.sort!
# smalldata = [bigdata[0]]
# (1...bigdata.size).each do |i|
#   smalldata << (bigdata[i] - smalldata[i-1])
# end
# puts ""
# puts "Bigdata:"
# puts bigdata.size
# puts "Smalldata"
# puts smalldata.size
# puts Marshal.dump(smalldata).size
# puts "Compressed: #{Zlib::Deflate.deflate(Marshal.dump(smalldata)).size}"
# puts Marshal.dump(smalldata.map(&:to_s)).size
# puts "Compressed: #{Zlib::Deflate.deflate(Marshal.dump(smalldata.map(&:to_s))).size}"
###### END OF CODE
# This yields that sorting and storing it as a sequence that can be added up gives us about 4% less storage for integer
# and 2% less storage for string representaion of numbers. 
# Compression gives us 35% less memory for integer values. When using the sorted and sequenced data we can even save 48% memory compare to the raw integer data
# For string data the behavious is the same but the most effient storage of the string numbers is still about 28% bigger than the most efficient integer storage.
class AquaResult
	require "base64"
	
	def self.create(attrs)
		ret = AquaResult.new([])
		ret.instance_variables.each do |attr|
			val = attrs[attr.to_s.gsub(/^@/, "")]
			ret.instance_variable_set(attr.to_sym, val)
		end
		ret
	end
	
	def initialize(data)
		raise ArgumentError.new("data has to be an array") unless data.is_a?(Array)
		raise ArgumentError.new("data has to be an array of numbers") unless data.all?{|i| i.is_a? Numeric}
		@size = data.size
		save(data)
	end
	
	def md5sum
		@md5sum
	end
	
	def data
		@data
	end
	
	def size
		(@size || self.load.size)
	end
	
	def save(bigdata)
		@size = bigdata.size
		@data = toBase64 zip serialize pack sequence bigdata
		@md5sum =  Digest::MD5.hexdigest(@data)
		true
	end
	
	def load()
		md5sum_now = Digest::MD5.hexdigest(@data)
		raise "Data is corrupt" if md5sum_now != @md5sum.to_s
		bigdata = unsequence unpack unserialize unzip fromBase64 @data
		if @size > 0
			raise "Data could not be loaded. (#{bigdata.size} == #{@size.to_i}) " unless bigdata.size == @size.to_i
		else
			bigdata = bigdata.reject(&:nil?)
			raise "Data could not be loaded. (#{bigdata.size} == #{@size.to_i}) " unless bigdata.size == @size.to_i
		end
		bigdata
	end
	
	def sequence(arr)
		bigdata = arr.sort # if we do it in place this will mess up other the calling code...
		smalldata = [bigdata[0]]
		(1...bigdata.size).each do |i|
			smalldata << (bigdata[i] - smalldata[i-1])
		end
		smalldata
	end
	
	def unsequence(arr)
		bigdata = [arr[0]]
		(1...arr.size).each do |i|
			bigdata << (arr[i] + arr[i-1])
		end
		bigdata
	end
	
	def zip(str)
		Zlib::Deflate.deflate(str)
	end
	
	def unzip(str)
		Zlib::Inflate.inflate(str)
	end
	
	def pack(arr)
		arr.pack("w"*@size)
	end
	
	def unpack(str)
		str.unpack("w"*@size)
	end
	
	def serialize(obj)
		Marshal.dump(obj)
	end
	
	def unserialize(str)
		Marshal.load(str)
	end
	
	def toBase64(str)
		Base64.encode64(str)
	end
	
	def fromBase64(str)
		Base64.decode64(str)
	end
	
end