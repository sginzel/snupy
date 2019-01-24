require 'test_helper'

class UsersControllerTest < ActionController::TestCase
  setup do
    @user = users(:normal_user)
    @user.name << "_test"
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:users)
  end

  test "should get new" do
    get :new, _user: "admin"
    assert_response :success
  end

  test "should create user" do
    assert_difference('User.count') do
      post :create, user: { email: @user.email, full_name: @user.full_name, is_admin: @user.is_admin, name: @user.name }, _user: "admin"
    end

    assert_redirected_to user_path(assigns(:user))
  end

  test "should show user" do
    get :show, id: @user
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @user, _user: "admin"
    assert_response :success
  end

  test "should update user" do
    put :update, id: @user, user: { email: @user.email, full_name: @user.full_name, is_admin: @user.is_admin, name: @user.name }, _user: "admin"
    assert_redirected_to user_path(assigns(:user))
  end

  test "should destroy user" do
    assert_difference('User.count', -1) do
      delete :destroy, id: @user, _user: "admin"
    end

    assert_redirected_to users_path
  end
end
