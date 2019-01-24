ENV["RAILS_ENV"] = "test"
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

# https://apidock.com/rails/v3.2.8/ActiveRecord/TestFixtures/ClassMethods/fixtures
# http://stackoverflow.com/questions/35046327/configuring-fixture-path-in-activerecord-test-fixtures
class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  # Add more helper methods to be used by all tests here...

  # Runs assert_difference with a number of conditions and varying difference
  # counts.
  #
  # Call as follows:
  #
  # assert_differences([['Model1.count', 2], ['Model2.count', 3]])
  # http://wholemeal.co.nz/blog/2011/04/06/assert-difference-with-multiple-count-values/
  def assert_differences(expression_array, message = nil, &block)
    b = block.send(:binding)
    before = expression_array.map { |expr| eval(expr[0], b) }

    yield

    expression_array.each_with_index do |pair, i|
      e = pair[0]
      difference = pair[1]
      error = "#{e.inspect} didn't change by #{difference}"
      if message.is_a?(Array)
        error = "#{message[i]}\n#{error}" if message[i]
      else
        error = "#{message}\n#{error}" if message
      end
      assert_equal(before[i] + difference, eval(e, b), error)
    end
  end

  def assert_ability(uname, action, object, message = "")
    user = users(uname)
    ability = Ability.new(user)
    assert ability.can?(action, object), message
  end

  def assert_inability(uname, action, object, message = "")
    user = users(uname)
    ability = Ability.new(user)
    assert ability.cannot?(action, object), message
  end

end
