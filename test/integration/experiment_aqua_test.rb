require 'test_helper'

class ExperimentAquaTest < ActionDispatch::IntegrationTest
	setup do
		@experiment = experiments(:experiment)
	end

	test "Aqua Page" do

		get "/experiments/#{@experiment.id}"
		assert_response :success, "Experiment details"

		get "/experiments/#{@experiment.id}/aqua", _user: "foreign_user"
		# assert_select "h1", "Welcome#index"
		assert_response 302 # foreign users shouldnt be able to access the experiemnt

		get "/experiments/#{@experiment.id}/aqua"
		assert_response :success

		post "/experiments/#{@experiment.id}/aqua", {commit: "OK", commit_action: "query"}
		assert_response 400, "Querying without samples didnt give the expected error"

	end

	test "Aqua HTML request" do
		post "/experiments/#{@experiment.id}/aqua", {
				commit: "OK", commit_action: "query",
				samples: @experiment.sample_ids,
				format: "html",
				queries: {
						query_variation_call: {
								read_depth: {
										value: 10,
										filters: {"FilterVariationCall"=>{"vcdp"=>"1"}},
										combine: "AND"
								}
						}
				},
				aggregations: {
						group: {
								aggregation_group_by: {
										group_by_variation: "0"
								}
						},
						attribute: {
								"aggregation_variation_call" => {
										coordinates: "1",
										read_depth: "1",
										genotype: "1"

								}
						}
				}
		}
		assert_response :success, "Minimal query didnt succeed."
	end

	test "Aqua JSON request" do
		assert @experiment.sample_ids.size > 0, "Experiment cotains no samples."
		post "/experiments/#{@experiment.id}/aqua", {
				commit: "OK", commit_action: "query",
				samples: @experiment.sample_ids,
				format: "json",
				queries: {
						query_variation_call: {
								read_depth: {
										value: 0,
										filters: {"FilterVariationCall"=>{"vcdp"=>"1"}},
										combine: "AND"
								}
						}
				},
				aggregations: {
						group: {
								aggregation_group_by: {
										group_by_variation: "0"
								}
						},
						attribute: {
								"aggregation_variation_call" => {
										coordinates: "1",
										read_depth: "1",
										genotype: "1"

								}
						}
				}
		}
		var_calls_in_exp = @experiment.variation_calls.size
		result = ActiveSupport::JSON.decode @response.body
		assert result.size == var_calls_in_exp, "Minimal query didnt succeed. #{result.size} instead of #{var_calls_in_exp}"
	end

end