require 'test_helper'

class UserTest < ActiveSupport::TestCase
	test "Access to samples" do
		normal_user = users(:normal_user)
		vis_samples = normal_user.visible(Sample)
		assert normal_user.samples.all?{|s| vis_samples.include?(s) }, "User samples are not a subset of the visible samples"
	end
end
