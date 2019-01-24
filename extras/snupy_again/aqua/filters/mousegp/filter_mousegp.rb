class FilterMousegp < SimpleFilter
	# filter_method can be a symbol for a method
	#               or a lambda: lambda{|value| "some_model_column IN (#{value.join(",")})"}
	create_filter_for QueryMousegp, :query_mousegp,
					  name: :some_filter_name,
					  label: "Some label",
					  filter_method: :some_filter_method,
					  collection_method: :find_possibilities,
					  organism: [organisms(:human), organisms(:mouse)],
					  checked: false,
					  requires: {
						  Mousegp => [:some_attr]#,
						  #SomeOtherModel => [:another_attribute] # you may reqiure information from other models as well. Remember to check for the existnace in the applicable? method
					  },
					  tool: Mousegp
	
	# return a SQL condition here.
	def some_filter_method(value)
		"some_attr = '#{value}'"
	end
	
	# in case of ComplexFilter - filter the array
	# def some_filter_method(arr, value)
	# 	arr.select{|rec| rec['some_attr'] == value}
	# end
	
	# returns a array of hashes containting
	def find_possibilities
		[
			{id: "some_val", label: "Anthing else", column2: "can go here"},
			{id: "some_val1", label: "id columns", column2: "will be provided to some_filter_method"}
		]
	end
	
	def applicable?(organismid = nil)
		is_applicable = super
		# this may be used to check if other models exist or not.
		check_some_other_thing = !defined?(SomeOtherModel).nil?
		is_applicable && check_some_other_thing
	end
end
