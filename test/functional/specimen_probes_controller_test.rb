require 'test_helper'

class SpecimenProbesControllerTest < ActionController::TestCase
	setup do
		@specimen_probe = specimen_probes(:trio_child)
		@specimen_probe.name = @specimen_probe.name + "_test"
		@entity = @specimen_probe.entity
	end

	test "should get index" do
		get :index
		assert_response :success
		assert_not_nil assigns(:specimen_probe)
	end

	test "should get new" do
		get :new
		assert_response :success
	end

	test "should create specimen probe" do
		assert_difference('SpecimenProbe.count') do
			post :create,
					 specimen_probe: {
							 name: @specimen_probe.name,
							 notes: @specimen_probe.notes,
							 entity_id: @entity.id
					 },
					 tags: {
							 'STATUS' => tags(:tag_mother),
							 'TISSUE' => tags(:tag_tissue)
					 }
		end
		assert :success
		# assert_redirected_to entity_path(assigns(:entity))
	end

	test "should show specimen probe" do
		get :show, id: @specimen_probe
		assert_response :success
	end

	test "should get edit" do
		get :edit, id: @specimen_probe
		assert_response :success
	end

	test "should update specimen probe" do
		put :update, id: @specimen_probe, entity: {
				name: @specimen_probe.name + "_updated_name",
				notes: @specimen_probe.notes }
		assert :success
		# assert_redirected_to entity_path(assigns(:entity))
	end

	test "should destroy specimen probe" do
		assert_difference('SpecimenProbe.count', -1) do
			delete :destroy, id: @specimen_probe, _user: "data_manager"
		end
		assert_redirected_to specimen_probes_path
	end

	test "should assign sample" do
		assert false
	end
	test "should assign entity" do
		assert false
	end

end
