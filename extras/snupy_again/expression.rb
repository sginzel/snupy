module SnupyAgain

	# The ExpressionDummy class is used to evaluate whatever expression the user submits
	class ExpressionDummy
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

	class Expression

		def self.klass
			raise "not implemented klas"
		end

		def self.collection_klass
			ExpressionCollection
		end

		def self.operators
			%w(+ - | & ( ) [ ])
		end

		def self.allowed_characters()
			%w(0 1 2 3 4 5 6 7 8 9) + (65..(65+25)).to_a.map(&:chr) + (97..(97+25)).to_a.map(&:chr) + ["\\"]
		end

		def self.quotes()
			%w(' ")
		end

		def self.allowed_words
			%w()
		end

		def self.split_by()
			""
		end

		def self.number_only
			false
		end

		def self.sanitize(str, class_to_instantiate)
			# allowed
			# operators +-|&()
			# ids [0-9]
			# conditions [.*] (everything is allowed between [])

			is_op = Hash[operators.map{|x| [x, true]}]
			is_op.default = false

			is_quote = Hash[quotes.map{|x| [x, true]}]
			is_quote.default = false

			is_allowed = Hash[(operators + quotes + allowed_characters).map{|x| [x, true]}]
			is_allowed.default = false

			inside_bracket = false
			open_brackets = 0

			inside_quote = false
			quote_char = nil

			newstr = []
			previous_chr = nil
			str.split(split_by).each_with_index do |chr, i|
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
				if is_quote[chr] && !inside_quote then # start of quote
					inside_quote = true
					quote_char = chr
					next
				elsif is_quote[chr] && inside_quote && quote_char == chr then # end of quote
					# check if previous character was not a backslash
					if previous_chr != "\\" then
						inside_quote = false
						quote_char = nil
						next
					end
				end
				next unless (inside_bracket | is_allowed[chr] | (inside_quote && chr == " "))
				previous_chr = chr
				newstr << chr
			end
			# we got the string sanitized for invalid characters
			# now join the characters to valid words
			# this is where we should use a grammar or at least a tree
			t = Trie.new
			mywords = allowed_words.map(&:downcase)
			mywords.each do |w|
				t.add w, 1
			end

			words = []
			currword = ""
			newstr.each do |chr|
				if (is_op[chr])
					# there is a possiblity that words contain operators, so we want to check if extending the current word
					# with that operator would yield any results in the database
					if currword != "" and t.children((currword + chr).downcase).size == 0 then
						# check if the word we want to add is equal to one of the allowed words
						check_word(currword, mywords, t)
						words << "#{class_to_instantiate.name}.new(\"" + currword + "\")" unless currword == ""
						words << chr
						currword = ""
						next
					end
				end
				extended = currword + chr
				# check if current word is valid
				if t.children(extended.downcase).size > 0 then
					currword = extended
				else # if not skip it
					if !is_op[chr] then
						raise ExpressionInvalidWordException.new("'#{currword}' is not a valid expression. Did you mean: #{t.children(currword.downcase)[0..5].join(" or ")}?")
					else
						words << chr
					end
					next
				end
			end
			check_word(currword, mywords, t)
			words << "#{class_to_instantiate.name}.new(\"" + currword + "\")" unless currword == ""

			return words.join("")
		end

		def self.check_word(currword, words, t)
			if currword != "" and !words.any?{|x| x == currword.downcase}
				possiblities = t.children(currword.downcase)
				raise ExpressionInvalidWordException.new("#{currword} is not a valid expression. Did you mean: #{possiblities[0..5].join(" or ")}?")
			end
			#if currword != "" and t.children(currword.downcase).size > 1 then
			#	possiblities = t.children(currword.downcase)
			#	raise ExpressionInvalidWordException.new("#{currword} is not a unique expression. #{possiblities[0..5].join(" or ")} are possible (total: #{possiblities.size}).")
			#end
		end

		def self.parse(str)
			# ss = eval sanitize(str, self)
			# sanitize removes everything that doesnt look right.
			# it also inserts the class initialization at the correct places
			# mening that numbers inside [] are not treated as sample IDS
			begin
				safe_test = sanitize(str.dup, ExpressionDummy)
				# After ruby 2.1 this wont work anymore.
				# -> http://ruby-doc.org/stdlib-2.4.2/libdoc/erb/rdoc/ERB.html might be a solution.
				
				# we then setup a new Thread with a high security level that prevents nasty things such as chown, chroot, Kernel.eval and such
				# this thread evaluates the expression using the ExpressionDummy and checks whether the return value is valid.
				if (1 == 0)
					safe_test.taint
					ss = nil
					t = Thread.start{
						$SAFE = 1 # previous to ruby 2.1 you want to set this to 4
						ss = eval safe_test
					}.join
				else
					d "Warning - EXPRESSION PARSING IS NOT COOL ANYMORE"
					ss = eval safe_test
				end
				raise ExpressionParseException.new("Not a valid expression.") unless ss.is_a?(ExpressionDummy)
				# replace all numbers xxx with Sample.find(xxx)
				str = sanitize(str, self)
				# str = str.gsub(/([0-9]+)/, "Expression.new(\\1)")
				ss = eval str
				raise ExpressionParseException.new("Not a valid expression") unless ss.is_a?(Expression) | ss.is_a?(ExpressionCollection)
				return ss
			rescue SyntaxError => e
				raise ExpressionParseException.new("#{str} is an invalid expression")
			end

		end

		def collection_klass
			self.class.collection_klass
		end

		def initialize(word, value_method_or_relation)
			@entity = get_entity(word)
			if (value_method_or_relation.is_a?(Symbol))
				@values = @entity.send(value_method_or_relation)
			else
				@values = value_method_or_relation
			end

		end

		def entity
			@entity
		end

		def values
			@values
		end

		def get_entity(word)
			raise "not implemented"
		end

		def [](*opts)
			raise "Conditions cannot be applied anymore." unless self.values.is_a?(ActiveRecord::Relation)
			self.class.new( @entity, self.values.where(*opts))
		end

		def +(othr)
			self.class.collection_klass.new [self, othr]
		end

		def -(othr)
			self.class.new([self.entity, othr.entity], self.values.flatten - othr.values.flatten)
		end

		def &(othr)
			self.class.new([self.entity, othr.entity], self.values.flatten & othr.values.flatten)
		end

		def |(othr)
			self.class.new([self.entity, othr.entity], self.values.flatten | othr.values.flatten)
		end

	end

	class ExpressionCollection
		attr_accessor :sets

		def expression_klass
			ret = @sets.first
			while (ret.is_a?(Array))
				ret = ret.first
			end
			ret.class
		end

		def expression_collection_klass
			ret = @sets.first
			while (ret.is_a?(Array))
				ret = ret.first
			end
			ret.collection_klass
		end

		def initialize(*sets)
			@sets = sets
		end

		def sets
			@sets
		end

		def entity
			self.map{|ss|
				ss.entity
			}
		end

		def entities
			entity()
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
			if othr.is_a?(ExpressionCollection) then
				expression_collection_klass.new(self.sets + othr.sets)
			else
				expression_collection_klass.new(self.sets + [othr])
			end
		end

		def -(othr)
			expression_klass.new([self.entity, othr.entity], self.values.flatten - othr.values.flatten)
		end

		def &(othr)
			expression_klass.new([self.entity, othr.entity], self.values.flatten & othr.values.flatten)
		end

		def |(othr)
			expression_klass.new([self.entity, othr.entity], self.values.flatten | othr.values.flatten)
		end

		def values()
			self.map{|ss|
				ss.values
			}
		end
	end

	class ExpressionParseException < StandardError
	end

	class ExpressionInvalidWordException < ExpressionParseException
	end



end