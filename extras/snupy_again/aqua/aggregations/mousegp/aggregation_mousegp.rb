class AggregationMousegp < Aggregation
	# provide all attributes of a model through the AQuA API
	# batch_attributes(Mousegp)
	
	
	register_aggregation :aggregation_mousegp,
						 label: "Some Label",
						 colname: "Some Attribtue",
						 prehook: :some_prehook, # OPTIONAL used for calculation that need to happen before the aggregation. Such as counting. :posthook is also possible to modify array after aggregation.
						 colindex: -1,
						 aggregation_method: :some_attribute_method,
						 type: :attribute,
						 checked: false,
						 category: :mousegp,
	                     active: false,
						 requires: {
							 Mousegp => [:some_model_attr]
						 }
	
	register_aggregation :aggregation_mousegp1,
						 label: "Some other label",
						 colname: "Some other attr",
						 colindex: 3.1,
						 aggregation_method: lambda{|rec|
							rec["some_attribute"]
						 },
						 type: :attribute,
						 record_color: {
							 "Some other attr" => :factor
						 },
						 checked: true,
						 category: :mousegp,
						 active: false,
						 requires: {
							 Mousegp => ["some_attribute"]
						 }
	
	def some_attribute_method(rec)
		"SOME PREFIX: #{rec['some_model_attr']} COUNTS: (#{@counter[rec['some_model_attr']]})"
	end
	
	def some_prehook(arr)
		@counter = Hash.new(0)
		# group key is used to group records of the database into groups, such as by variantion_id or by overlapping region
		arr.each {|groupkey, recs|
			recs.map {|rec|
				@counter[rec['some_model_attr']] += 1
			}
		}
		
	end

end