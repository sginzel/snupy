require 'test_helper'

class EntitiesControllerTest < ActionController::TestCase
  setup do
    @entity = entities(:child1)
		@entity.name = @entity.name + "_test"
    @entity_group = @entity.entity_group
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:entities)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create entity" do
    assert_difference('Entity.count') do
      post :create,
					 entity: {
							name: @entity.name,
							nickname: @entity.nickname,
							notes: @entity.notes,
							entity_group_id: @entity_group.id
						},
					 tags: {
						"CLASS" => tags(:tag_class_shared_control)
						}
    end
		assert :success
    # assert_redirected_to entity_path(assigns(:entity))
	end

	test "should create entity with specimen_probes" do
		#assert_difference('Entity.count') do
		assert_differences([['Entity.count', 1], ['SpecimenProbe.count', 1]],
											 ['Entity not created', 'Specimen Could not be created or was created when it shouldnt have been.']) do
			post :create,
					 entity: {
							 name: @entity.name,
							 nickname: @entity.nickname,
							 notes: @entity.notes,
							 entity_group_id: @entity_group.id
					 },
					 tags: {
							 "CLASS" => tags(:tag_class_shared_control)
					 }, specimen_templates: {
							'1' => {
									name: @entity.name + '_spec1',
									tags: {
											'STATUS' => tags(:tag_mother),
											'TISSUE' => tags(:tag_tissue)
									}
							},
							'1.1' => {
									name: @entity.name + '_spec1',
									tags: {
											'STATUS' => tags(:tag_mother),
											'TISSUE' => tags(:tag_tissue)
									}
							},
							'2' => {
									name: @entity.name + '_spec2',
									tags: {
											'STATUS' => tags(:tag_mother)
									}
							}
					}
		end
		assert :success
		# assert_redirected_to entity_path(assigns(:entity))
	end

  test "should show entity" do
    get :show, id: @entity
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @entity
    assert_response :success
  end

  test "should update entity" do
    put :update, id: @entity, entity: { name: @entity.name + "_updated_name", nickname: @entity.nickname, notes: @entity.notes }
		assert :success
    # assert_redirected_to entity_path(assigns(:entity))
  end

  test "should destroy entity" do
    assert_difference('Entity.count', -1) do
      delete :destroy, id: @entity, _user: "data_manager"
    end
    assert_redirected_to entities_path
	end

	test "should assign entity group" do
		assert false
	end

	test "should assign specimen probe" do
		assert false
	end

end
