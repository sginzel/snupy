require 'test_helper'

class ExperimentsControllerTest < ActionController::TestCase
  setup do
    @experiment = experiments(:experiment)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:experiments)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create experiment" do
    assert_difference('Experiment.count') do
      post :create, experiment: { contact: @experiment.contact, description: @experiment.description, institution_id: @experiment.institution.id, name: @experiment.name, title: @experiment.title }
    end

    assert_redirected_to experiment_path(assigns(:experiment))
  end

  test "should show experiment" do
    get :show, id: @experiment
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @experiment
    assert_response :success
  end

  test "should update experiment" do
    put :update, id: @experiment, experiment: { contact: @experiment.contact, description: @experiment.description, institution_id: @experiment.institution.id, name: @experiment.name, title: @experiment.title }
    assert_redirected_to experiment_path(assigns(:experiment))
  end

  test "should destroy experiment" do
    assert_difference('Experiment.count', 0) do
      delete :destroy, id: @experiment.id
		end
		assert_difference('Experiment.count', -1) do
			delete :destroy, id: @experiment.id, _user: "admin"
		end
    assert_redirected_to experiments_path
	end

	test "foreign user can't access query page" do
		fuser = users(:foreign_user)
		fability = Ability.new(fuser)
		assert fability.cannot?(:aqua, @experiment)
		#get :aqua, id: @experiment.id, _user: "foreign_user"
		## assert_select "h1", "Welcome#index"
		#assert_response 302, "Foreign user shouldn't be able to access the query mask" # foreign users shouldn't be able to access the experiment
	end

	test "normal user should use aqua" do

		nuser = users(:normal_user)
		nability = Ability.new(nuser)
		assert nability.can?(:aqua, @experiment)

		#get :aqua, id: @experiment.id
		#assert_response :success

	end

	test "should give error when no samples selected" do
		# post "/experiments/#{@experiment.id}/aqua", {commit: "OK", commit_action: "query"}
		post :aqua, id: @experiment.id, commit: "OK", commit_action: "query"
		assert_response 400, "Querying without samples didnt give the expected error"
	end

	test "should return AQUA html" do
		#post "/experiments/#{@experiment.id}/aqua", {
		post :aqua, id: @experiment.id,
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

		assert_response :success, "Minimal query didnt succeed."
	end

	test "Should return AQUA json" do
		@experiment = experiments(:experiment)
		assert @experiment.sample_ids.size > 0, "Experiment cotains no samples."
		# post "/experiments/#{@experiment.id}/aqua", {
		post :aqua, id: @experiment.id,
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
		var_calls_in_exp = @experiment.variation_calls.size
		result = ActiveSupport::JSON.decode @response.body
		assert result.size == var_calls_in_exp, "Minimal JSON query didnt succeed. #{result.size} instead of #{var_calls_in_exp}"
	end

	test "should have meta experiment" do
		# metaid = Experiment.meta_experiment_for(users(:normal_user), organisms(:homo_sapiens), true)
		user = users(:normal_user)
		org = organisms(:homo_sapiens)
		get :aqua_meta, id: @experiment.id, user: user.id, organism: org.id
		assert :success
	end

	test "Should look up variants in other samples" do
		post :details, ids: variation_calls(:variant_trio_child_recessive), experiment: @experiment.id, format: "json"
		result = ActiveSupport::JSON.decode @response.body
		smpls = variation_calls(:variant_trio_child_recessive).variation.samples.where("samples.id" => @experiment.samples)
		# one variant for each sample
		assert smpls.size == result.size , "Query Details delivered wrong number of variants."
	end

	## cant fully test the interactions because it requires importing the interaction data....
	test "Should Show interactions" do
		post :interactions, ids: [variation_calls(:variant_trio_child_recessive)], experiment: @experiment.id
		assert :success, "cant show interaction"
	end

end
