class AggregationCaptureKit < Aggregation
	# provide all attributes of a model through the AQuA API
	# batch_attributes(CaptureKit)
	
	
	# register_aggregation :aggregation_capture_kit,
	# 					 label: "Capture Kit",
	# 					 colname: "Capture Kit Distance",
	# 					 prehook: :retrieve_capture_files, # OPTIONAL used for calculation that need to happen before the aggregation. Such as counting. :posthook is also possible to modify array after aggregation.
	# 					 colindex: 5,
	# 					 aggregation_method: :show_distances_to_targets,
	# 					 type: :attribute,
	# 					 checked: false,
	# 					 category: "Capture Kit",
	# 					 record_color: {
	# 							 "Capture Kit Distance" => {
	# 									 /.*0bp.*/ => "palegreen"
	# 							 }
	# 					 },
	# 					requires: {
	# 							CaptureKit => [:dist, :capture_kit_file_id]
	# 					 }
	cnt = 0.001
	CaptureKitFile.select([:name, :id]).all.each do |ckf|
		ckfname = ckf.name.gsub(" ", "_")
		ckfid = ckf.id
		register_aggregation :"aggregation_capture_kit_#{ckfname}",
												 label: "Capture Kit #{ckfname}",
												 colname: "#{ckfname}",
												 prehook: :retrieve_capture_files, # OPTIONAL used for calculation that need to happen before the aggregation. Such as counting. :posthook is also possible to modify array after aggregation.
												 colindex: 5+cnt,
												 aggregation_method: lambda{|rec, params, ckfobj=ckf|
													 id = rec["#{CaptureKit.aqua_table_alias}.capture_kit_file_id"]
													 if (id == ckfobj.id)
														 rec["#{CaptureKit.aqua_table_alias}.dist"]
													 else
														 nil
													 end
												 },
												 type: :attribute,
												 checked: false,
												 category: "Capture Kit",
												 color: {
														 "#{ckfname}" => create_color_gradient([-100, -25, 0, 25, 100], colors = ["salmon", "lightyellow", "palegreen", "lightyellow", "salmon"])
												 },
												 requires: {
														 CaptureKit => [:dist, :capture_kit_file_id]
												 }
		cnt += 0.001
	end

	def show_distances_to_targets(rec)
		ckf = @capture_files_lookup[rec["#{CaptureKit.aqua_table_alias}.capture_kit_file_id"].to_i]
		"#{ckf.name}(#{rec["#{CaptureKit.aqua_table_alias}.dist"]}bp)"
	end
	
	def retrieve_capture_files(arr)
		@capture_files_lookup = Hash.new(0)
		CaptureKitFile.select([:id, :name, :description, :bp, :chromosomes, :organism_id]).each do |ckf|
			@capture_files_lookup[ckf.id] = ckf
		end
	end

end