module SnupyAgain
	
	# The SampleSetDummy class is used to evaluate whatever expression the user submits 
	class SampleSetDummy
		def initialize(x)
			self
		end
		def +(othr)
			self
		end
		def -(othr)
			self
		end
		def &(othr)
			self
		end
		def |(othr)
			self
		end
		def [](*opts)
			self
		end
	end
	
	class SampleSet
		
		def self.sanitize(str, class_to_instantiate)
			# allowed
			# operators +-|&()
			# ids [0-9]
			# conditions [.*] (everything is allowed between [])
			allowed = Hash[%w(+ - | & ( ) 0 1 2 3 4 5 6 7 8 9 [ ]).map{|x| [x, true]}]
			allowed.default = false
			inside_bracket = false
			open_brackets = 0
			number_begun = nil
			newstr = []
			str.split("").each_with_index do |chr, i|
				# puts newstr.join("")
				# puts "[#{i}]------------------- #{chr}#{inside_bracket}#{open_brackets}"
				if chr == "[" then
					open_brackets += 1
					inside_bracket = true
					# newstr << chr
					# next
				end
				if chr == "]" && inside_bracket then
					open_brackets -= 1
					inside_bracket = open_brackets > 0
					# newstr << chr
					# next
				end
				next unless (inside_bracket | allowed[chr])
				# number found
				if chr =~ /[0-9]/ && !inside_bracket then
					#number starts
					if number_begun.nil?
						number_begun = i
						newstr[number_begun] = "#{class_to_instantiate.name}.new("
					end
					newstr[number_begun] << chr
					# newstr << nil
					next
				end
				# number ends
				# puts "#{chr.pretty_inspect} - #{number_begun.pretty_inspect} - #{inside_bracket.pretty_inspect}"
				if !(chr =~ /[0-9]/) && !number_begun.nil? & !inside_bracket then
					#newstr << nil
					# newstr[number_begun] = "#{class_to_instantiate.name}.new(#{current_number})"
					newstr[number_begun] << ")"
					number_begun = nil
				end
				newstr << chr
			end
			newstr.join("")
		end
		
		
		def self.parse(str)
			ss = eval sanitize(str, SampleSet)
			# sanitize removes everything that doesnt look right.
			# it also inserts the class initialization at the correct places
			# mening that numbers inside [] are not treated as sample IDS
			safe_test = sanitize(str.dup, SampleSetDummy)
			# we then setup a new Thread with a high security level that prevents nasty things such as chown, chroot, Kernel.eval and such
			# this thread evaluates the expression using the SampleSetDummy and checks whether the return value is valid. 
			safe_test.taint
			ss = nil
			if (1 == 0)
				t = Thread.start{
					$SAFE = 1 # previous to ruby 2.1 you want to set this to 4
					ss = eval safe_test
				}.join
			else
				d "Warning - EXPRESSION PARSING IS NOT COOL ANYMORE"
				ss = eval safe_test
			end
			raise SyntaxError.new("Not a valid sample set.") unless ss.is_a?(SampleSetDummy)
			# replace all numbers xxx with Sample.find(xxx)
			str = sanitize(str, SampleSet)
			# str = str.gsub(/([0-9]+)/, "SampleSet.new(\\1)")
			ss = eval str
			raise SyntaxError.new("Not a valid sample set") unless ss.is_a?(SampleSet) | ss.is_a?(SampleSetCollection)
			ss
		end
		
		def initialize(sampleid, varids = nil)
			@id = sampleid
			if sampleid.is_a?(Integer)
				@sample = Sample.find(sampleid)
				@varids = VariationCall.where(sample_id: sampleid)
			else
				@sample = sampleid
				@varids = varids
			end
			self
		end
		
		def [](*opts)
			raise "Conditions cannot be applied anymore." if !@varids.is_a?(ActiveRecord::Relation)
			SampleSet.new(self.sample, @varids.where(*opts))
		end
		
		def sample()
			@sample
		end
		
		def sample=(newsmpl)
			@sample = newsmpl
		end
		
		def varids()
			if @sample.is_a?(Sample)
				@varids = @varids.select(:variation_id).uniq.pluck(:variation_id)
				@sample = @sample.id
			end
			@varids
		end
		
		def varids=(newvarids)
			@varids = newvarids
		end
		
		def variation_call_ids
			VariationCall.where(variation_id: self.varids.flatten).where(sample_id: @sample.flatten).pluck(:id).uniq
		end
		
		def +(othr)
			SampleSetCollection.new ([self, othr])
		end
		
		def -(othr)
			SampleSet.new([self.sample, othr.sample], self.varids - othr.varids)
		end
		
		def &(othr)
			SampleSet.new([self.sample, othr.sample], self.varids & othr.varids)
		end
		
		def |(othr)
			SampleSet.new([self.sample, othr.sample], self.varids | othr.varids)
		end
		
	end
	
	class SampleSetCollection
		attr_accessor :sets
		
		def initialize(*sets)
			@sets = sets
		end
		
		def each(&block)
			return @sets unless block_given?
			@sets.flatten.each do |ss|
				yield ss
			end
		end
		
		def map(&block)
			return @sets unless block_given?
			@sets.flatten.map do |ss|
				yield ss
			end
		end
		
		def +(othr)
			SampleSetCollection.new(self.sets + othr.sets)
		end
		
		def -(othr)
			SampleSet.new([self.sample, othr.sample], self.varids - othr.varids)
		end
		
		def &(othr)
			SampleSet.new([self.sample, othr.sample], self.varids & othr.varids)
		end
		
		def |(othr)
			SampleSet.new([self.sample, othr.sample], self.varids | othr.varids)
		end
		
		def varids()
			self.map{|ss|
				ss.varids
			}
		end
		
		def variation_call_ids
			self.map{|ss|
				ss.variation_call_ids
			}
		end
		
	end
end