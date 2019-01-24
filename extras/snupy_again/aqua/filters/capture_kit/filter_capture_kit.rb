class FilterCaptureKit < SimpleFilter
	# filter_method can be a symbol for a method
	#               or a lambda: lambda{|value| "some_model_column IN (#{value.join(",")})"}
	create_filter_for QueryCaptureKit, :query_capture_kit,
					  name: :direct_hit,
					  label: "Hits target (dist = 0)",
					  filter_method: lambda{|value| "#{CaptureKit.aqua_table_alias}.dist = 0 AND #{CaptureKit.aqua_table_alias}.capture_kit_file_id IN (#{value.join(",")})"},
					  collection_method: :find_capture_file_kits,
					  organism: [organisms(:human), organisms(:mouse)],
					  checked: false,
					  requires: {
						  CaptureKit => [:dist, :capture_kit_file_id]
					  },
					  tool: CaptureKit

	create_filter_for QueryCaptureKit, :query_capture_kit,
										name: :hits_within10,
										label: "Hits target (dist <= 10)",
										filter_method: lambda{|value| "ABS(#{CaptureKit.aqua_table_alias}.dist) <= 10 AND #{CaptureKit.aqua_table_alias}.capture_kit_file_id IN (#{value.join(",")})"},
										collection_method: :find_capture_file_kits,
										organism: [organisms(:human), organisms(:mouse)],
										checked: false,
										requires: {
												CaptureKit => [:dist, :capture_kit_file_id]
										},
										tool: CaptureKit

	create_filter_for QueryCaptureKit, :query_capture_kit,
										name: :hits_within50,
										label: "Hits target (dist <= 50)",
										filter_method: lambda{|value| "ABS(#{CaptureKit.aqua_table_alias}.dist) <= 50 AND #{CaptureKit.aqua_table_alias}.capture_kit_file_id IN (#{value.join(",")})"},
										collection_method: :find_capture_file_kits,
										organism: [organisms(:human), organisms(:mouse)],
										checked: true,
										requires: {
												CaptureKit => [:dist, :capture_kit_file_id]
										},
										tool: CaptureKit

	create_filter_for QueryCaptureKit, :query_capture_kit,
										name: :hits_within100,
										label: "Hits target (dist <= 100)",
										filter_method: lambda{|value| "ABS(#{CaptureKit.aqua_table_alias}.dist) <= 100 AND #{CaptureKit.aqua_table_alias}.capture_kit_file_id IN (#{value.join(",")})"},
										collection_method: :find_capture_file_kits,
										organism: [organisms(:human), organisms(:mouse)],
										checked: false,
										requires: {
												CaptureKit => [:dist, :capture_kit_file_id]
										},
										tool: CaptureKit

	create_filter_for QueryCaptureKit, :query_capture_kit,
										name: :hits_offtargetmax,
										label: "Off-Target (>#{CaptureKitAnnotation.config('maxdist')})",
										filter_method: lambda{|value| "#{CaptureKit.aqua_table_alias}.dist IS NULL AND #{CaptureKit.aqua_table_alias}.capture_kit_file_id IN (#{value.join(",")})"},
										collection_method: :find_capture_file_kits,
										organism: [organisms(:human), organisms(:mouse)],
										checked: false,
										requires: {
												CaptureKit => [:dist, :capture_kit_file_id]
										},
										tool: CaptureKit
	create_filter_for QueryCaptureKit, :query_capture_kit,
										name: :hits_offtarget_100,
										label: "Off-Target (>100)",
										filter_method: lambda{|value| "(#{CaptureKit.aqua_table_alias}.dist IS NULL OR #{CaptureKit.aqua_table_alias}.dist > 100) AND #{CaptureKit.aqua_table_alias}.capture_kit_file_id IN (#{value.join(",")})"},
										collection_method: :find_capture_file_kits,
										organism: [organisms(:human), organisms(:mouse)],
										checked: false,
										requires: {
												CaptureKit => [:dist, :capture_kit_file_id]
										},
										tool: CaptureKit

	create_filter_for QueryCaptureKit, :query_capture_kit_on_target,
										name: :hits_onanytarget_exome,
										label: "On-Target Exome Capture",
										filter_method: lambda{|value| filter_by_hit_in_capture_kit_type('exome_capture')},
										collection_method: nil,
										organism: [organisms(:human), organisms(:mouse)],
										checked: true,
										requires: {
												CaptureKit => [:dist, :capture_kit_file_id]
										},
										tool: CaptureKit
	create_filter_for QueryCaptureKit, :query_capture_kit_on_target,
										name: :hits_onanytarget_genregion,
										label: "On-Target genetic regions",
										filter_method: lambda{|value| filter_by_hit_in_capture_kit_type('genetic_region')},
										collection_method: nil,
										organism: [organisms(:human), organisms(:mouse)],
										checked: false,
										requires: {
												CaptureKit => [:dist, :capture_kit_file_id]
										},
										tool: CaptureKit
	create_filter_for QueryCaptureKit, :query_capture_kit_on_target,
										name: :hits_onanytarget_regregion,
										label: "On-Target regulatory regions",
										filter_method: lambda{|value| filter_by_hit_in_capture_kit_type('regulatory_region')},
										collection_method: nil,
										organism: [organisms(:human), organisms(:mouse)],
										checked: false,
										requires: {
												CaptureKit => [:dist, :capture_kit_file_id]
										},
										tool: CaptureKit
	create_filter_for QueryCaptureKit, :query_capture_kit_on_target,
										name: :hits_onanytarget_other,
										label: "On-Target other",
										filter_method: lambda{|value| filter_by_hit_in_capture_kit_type('other')},
										collection_method: nil,
										organism: [organisms(:human), organisms(:mouse)],
										checked: false,
										requires: {
												CaptureKit => [:dist, :capture_kit_file_id]
										},
										tool: CaptureKit

	create_filter_for QueryCaptureKit, :query_capture_kit_on_target,
										name: :miss_onanytarget_exome,
										label: "Off-Target Exome Capture",
										filter_method: lambda{|value| filter_by_miss_in_capture_kit_type('exome_capture')},
										collection_method: nil,
										organism: [organisms(:human), organisms(:mouse)],
										checked: false,
										requires: {
												CaptureKit => [:dist, :capture_kit_file_id]
										},
										tool: CaptureKit
	create_filter_for QueryCaptureKit, :query_capture_kit_on_target,
										name: :miss_onanytarget_genregion,
										label: "Off-Target genetic regions",
										filter_method: lambda{|value| filter_by_miss_in_capture_kit_type('genetic_region')},
										collection_method: nil,
										organism: [organisms(:human), organisms(:mouse)],
										checked: false,
										requires: {
												CaptureKit => [:dist, :capture_kit_file_id]
										},
										tool: CaptureKit
	create_filter_for QueryCaptureKit, :query_capture_kit_on_target,
										name: :miss_onanytarget_regregion,
										label: "Off-Target regulatory regions",
										filter_method: lambda{|value| filter_by_miss_in_capture_kit_type('regulatory_region')},
										collection_method: nil,
										organism: [organisms(:human), organisms(:mouse)],
										checked: false,
										requires: {
												CaptureKit => [:dist, :capture_kit_file_id]
										},
										tool: CaptureKit
	create_filter_for QueryCaptureKit, :query_capture_kit_on_target,
										name: :miss_onanytarget_other,
										label: "Off-Target other regions",
										filter_method: lambda{|value| filter_by_miss_in_capture_kit_type('other')},
										collection_method: nil,
										organism: [organisms(:human), organisms(:mouse)],
										checked: false,
										requires: {
												CaptureKit => [:dist, :capture_kit_file_id]
										},
										tool: CaptureKit


	def filter_by_hit_in_capture_kit_type(capture_type)
		ids = CaptureKitFile.where(capture_type: capture_type).select([:id]).pluck(:id)
		"#{CaptureKit.aqua_table_alias}.dist = 0 AND #{CaptureKit.aqua_table_alias}.capture_kit_file_id IN (#{ids.join(",")})"
	end

	def filter_by_miss_in_capture_kit_type(capture_type)
		ids = CaptureKitFile.where(capture_type: capture_type).select([:id]).pluck(:id)
		"#{CaptureKit.aqua_table_alias}.dist IS NULL AND #{CaptureKit.aqua_table_alias}.capture_kit_file_id IN (#{ids.join(",")})"
	end
	# in case of ComplexFilter - filter the array
	# def some_filter_method(arr, value)
	# 	arr.select{|rec| rec['some_attr'] == value}
	# end
	
	# returns a array of hashes containting
	def find_capture_file_kits(params)
		exp = Experiment.where(id: params["experiment"]).first
		return [{error: "Cannot find experiment"}] if exp.nil?
		
		CaptureKitFile.select([:id, :name, :capture_type, :description, :bp, :chromosomes, :organism_id])
		.where(organism_id: exp.organism_id)
		.map{|ckf|
			{
				:id => ckf.id,
				:name => ckf.name,
				:capture_type => ckf.capture_type,
				:description => ckf.description,
				:bp => ckf.bp,
				:chromosomes => ckf.chromosomes,
				:organism => ckf.organism.name
			}
		}
	end

end
