require 'test_helper'

# noinspection ALL
class EntityGroupsControllerTest < ActionController::TestCase
  setup do
    @entity_group = entity_groups(:trio)
		@entity_group_other = entity_groups(:tumor_normal)
    # we need to make the name uniq if we want to use it as a template
    @entity_group.name = @entity_group.name + '_test'
  end

  test 'should get index' do
    get :index
    assert_response :success
    assert_not_nil assigns(:entity_groups)
  end

  test 'should get new' do
    get :new
    assert_response :success
  end

  test 'should create entity_group' do
    assert_difference('EntityGroup.count') do
      post :create, entity_group: { name: @entity_group.name, institution_id: @entity_group.institution.id, organism_id: @entity_group.organism.id }
    end
    assert :success
    # assert_redirected_to entity_group_path(assigns(:entity_group))
  end

	test 'should create entity_group with entity' do
		# assert_difference('EntityGroup.count') do
		assert_differences([['EntityGroup.count', 1], ['Entity.count', 2]],
											 ['Entity Group not created', 'Entity Could not be created']) do
			post :create, entity_group: {
					name: @entity_group.name,
					institution_id: @entity_group.institution.id,
					organism_id: @entity_group.organism.id,
			}, entity_templates: {
					'1' => {
							name: @entity_group.name + '_entity',
							tags: {
									'CLASS' => tags(:tag_class_malignant),
									'DISEASE' => tags(:tag_disease)
							}
					},
					'2' => {
							name: @entity_group.name + '_entity_shared_control',
							tags: {
									'CLASS' => tags(:tag_class_shared_control)
							}
					}
			}
		end
		assert :success
		# assert_redirected_to entity_group_path(assigns(:entity_group))
	end

  test 'should show entity_group' do
    get :show, id: @entity_group
    assert_response :success
  end

  test 'should get edit' do
    get :edit, id: @entity_group
    assert_response :success
  end

  test 'should update entity_group' do
    put :update, id: @entity_group, entity_group: { name: @entity_group.name }
    assert :success
    # assert_redirected_to entity_group_path(assigns(:entity_group))
  end

  test 'should destroy entity_group' do
    assert_difference('EntityGroup.count', -1) do
      delete :destroy, id: @entity_group, _user: "data_manager"
    end

    assert_redirected_to entity_groups_path
	end

	test 'should show dataset summary' do
		post :show_dataset_summary, ids: [@entity_group.id]
		assert_response :success
	end

	test 'should assign entities' do
		assert_difference('@entity_group.entities.count', 1) do
			othr_ent = entities(:child_tumor_normal)
			post :assign_entity, ids: [@entity_group.id],
					 entities: (@entity_group.entity_ids + [othr_ent.id]).map(&:to_s),
					 "internal_identifier"=>" ", "name"=>" ", "nickname"=>" "
			assert_response :success
		end
	end

end
