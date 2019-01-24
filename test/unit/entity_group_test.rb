require 'test_helper'

class EntityGroupTest < ActiveSupport::TestCase
	test "No Entiy Groupd without name" do
		eg = EntityGroup.new
		assert !eg.save
	end



  # test "the truth" do
  #   assert true
  # end
end
