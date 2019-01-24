# We need to make the parameter longer than 64Kb because meta experiment lists can be really long
# and the additional overhead from the query defition takes its toll as well.
class MakeJobParametersLonger < ActiveRecord::Migration
	def up
		change_column :long_jobs, :parameter, :text, limit: 16.megabytes - 1
	end
	
	# there really is no need to do anything when rolling back
	def down
	end
end
