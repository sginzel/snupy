module SnupyAgain

	class TagExpression < SnupyAgain::Expression

		def self.klass
			Tag
		end

		#def self.collection_class
		#	TagExpressionCollection
		#end

		def self.operators
			%w(+ - | & ( ))
		end

		def self.allowed_characters()
			%w(0 1 2 3 4 5 6 7 8 9 [ ] , .) + (65..(65+25)).to_a.map(&:chr) + (97..(97+25)).to_a.map(&:chr) + ["\\"]
		end

		def self.allowed_words
			Tag.pluck(:value).uniq
		end

		def self.split_by()
			""
		end

		def initialize(word, value_method_or_relation = :samples)
			super(word, value_method_or_relation)
		end

		def get_entity(word)
			word = word.flatten.map(&:value) if word.is_a?(Array)
			ent = self.class.klass.where(value: word).first
			ent = self.class.klass.new(object_type: "Sample") if ent.nil?
			ent
		end

	end

	# class TagExpressionCollection
	# 	attr_accessor :sets
	#
	# 	def initialize(*sets)
	# 		@sets = sets
	# 	end
	#
	# 	def each(&block)
	# 		return @sets unless block_given?
	# 		@sets.flatten.each do |ss|
	# 			yield ss
	# 		end
	# 	end
	#
	# 	def map(&block)
	# 		return @sets unless block_given?
	# 		@sets.flatten.map do |ss|
	# 			yield ss
	# 		end
	# 	end
	#
	# 	def +(othr)
	# 		TagExpressionCollection.new(self.sets + othr.sets)
	# 	end
	#
	# 	def -(othr)
	# 		Expression.new([self.sample, othr.sample], self.varids - othr.varids)
	# 	end
	#
	# 	def &(othr)
	# 		Expression.new([self.sample, othr.sample], self.varids & othr.varids)
	# 	end
	#
	# 	def |(othr)
	# 		Expression.new([self.sample, othr.sample], self.varids | othr.varids)
	# 	end
	#
	# 	def varids()
	# 		self.map{|ss|
	# 			ss.varids
	# 		}
	# 	end
	#
	# 	def variation_call_ids
	# 		self.map{|ss|
	# 			ss.variation_call_ids
	# 		}
	# 	end
	#
	# end
end