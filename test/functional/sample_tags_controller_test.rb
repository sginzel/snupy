require 'test_helper'

class SampleTagsControllerTest < ActionController::TestCase
  setup do
    @sample_tag = sample_tags(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:sample_tags)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create sample_tag" do
    assert_difference('SampleTag.count') do
      post :create, sample_tag: {  }
    end

    assert_redirected_to sample_tag_path(assigns(:sample_tag))
  end

  test "should show sample_tag" do
    get :show, id: @sample_tag
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @sample_tag
    assert_response :success
  end

  test "should update sample_tag" do
    put :update, id: @sample_tag, sample_tag: {  }
    assert_redirected_to sample_tag_path(assigns(:sample_tag))
  end

  test "should destroy sample_tag" do
    assert_difference('SampleTag.count', -1) do
      delete :destroy, id: @sample_tag
    end

    assert_redirected_to sample_tags_path
  end
end
