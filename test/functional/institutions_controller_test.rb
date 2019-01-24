require 'test_helper'

class InstitutionsControllerTest < ActionController::TestCase
  setup do
    @institution = institutions(:ukd)
		@institution.name << "_test"
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:institutions)
  end

  test "should get new" do
    get :new, _user: "admin"
    assert_response :success
  end

  test "should create institution" do
    assert_difference('Institution.count') do
      post :create, institution: { name: @institution.name }, _user: "admin"
    end

    assert_redirected_to institution_path(assigns(:institution))
  end

  test "should show institution" do
    get :show, id: @institution
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @institution, _user: "admin"
    assert_response :success
  end

  test "should update institution" do
    put :update, id: @institution, institution: { name: "new inst name"  }, _user: "admin"
    assert_redirected_to institution_path(assigns(:institution))
  end

  test "should destroy institution" do
    assert_difference('Institution.count', -1) do
      delete :destroy, id: @institution, _user: "admin"
    end

    assert_redirected_to institutions_path
  end
end
