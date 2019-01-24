require 'test_helper'

class LongJobsControllerTest < ActionController::TestCase
  setup do
    @long_job = long_jobs(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:long_jobs)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create long_job" do
    assert_difference('LongJob.count') do
      post :create, long_job: { delayed_job_id: @long_job.delayed_job_id, handle: @long_job.handle, method: @long_job.method, parameter: @long_job.parameter, status: @long_job.status, success: @long_job.success, title: @long_job.title, user: @long_job.user }
    end

    assert_redirected_to long_job_path(assigns(:long_job))
  end

  test "should show long_job" do
    get :show, id: @long_job
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @long_job
    assert_response :success
  end

  test "should update long_job" do
    put :update, id: @long_job, long_job: { delayed_job_id: @long_job.delayed_job_id, handle: @long_job.handle, method: @long_job.method, parameter: @long_job.parameter, status: @long_job.status, success: @long_job.success, title: @long_job.title, user: @long_job.user }
    assert_redirected_to long_job_path(assigns(:long_job))
  end

  test "should destroy long_job" do
    assert_difference('LongJob.count', -1) do
      delete :destroy, id: @long_job
    end

    assert_redirected_to long_jobs_path
  end
end
