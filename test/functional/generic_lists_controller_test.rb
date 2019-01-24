require 'test_helper'

class GenericListsControllerTest < ActionController::TestCase
  setup do
    @generic_list = generic_lists(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:generic_lists)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create generic_list" do
    assert_difference('GenericList.count') do
      post :create, generic_list: {  }
    end

    assert_redirected_to generic_list_path(assigns(:generic_list))
  end

  test "should show generic_list" do
    get :show, id: @generic_list
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @generic_list
    assert_response :success
  end

  test "should update generic_list" do
    put :update, id: @generic_list, generic_list: {  }
    assert_redirected_to generic_list_path(assigns(:generic_list))
  end

  test "should destroy generic_list" do
    assert_difference('GenericList.count', -1) do
      delete :destroy, id: @generic_list
    end

    assert_redirected_to generic_lists_path
  end
end
