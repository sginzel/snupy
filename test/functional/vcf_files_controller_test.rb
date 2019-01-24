require 'test_helper'

class VcfFilesControllerTest < ActionController::TestCase
  setup do
    @vcf_file = vcf_files(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:vcf_files)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create vcf_file" do
    assert_difference('VcfFile.count') do
      post :create, vcf_file: {  }
    end

    assert_redirected_to vcf_file_path(assigns(:vcf_file))
  end

  test "should show vcf_file" do
    get :show, id: @vcf_file
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @vcf_file
    assert_response :success
  end

  test "should update vcf_file" do
    put :update, id: @vcf_file, vcf_file: {  }
    assert_redirected_to vcf_file_path(assigns(:vcf_file))
  end

  test "should destroy vcf_file" do
    assert_difference('VcfFile.count', -1) do
      delete :destroy, id: @vcf_file
    end

    assert_redirected_to vcf_files_path
  end
end
