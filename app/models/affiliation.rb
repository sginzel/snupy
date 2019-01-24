class Affiliation < ActiveRecord::Base
	extend Enumerize
	belongs_to :user
	belongs_to :institution
	
	attr_accessible :user_id, :institution_id, :roles
	
	serialize :roles, Array
	enumerize :roles, in: [:user, :research_manager, :data_manager], default: :user, multiple: true # admin is still a user attribute
	# assignable_values_for :roles do
	# 	['admin', 'data_manager', 'research_manager', 'user']
	# end
	
	def self.create_from_params(user, institution_to_roles)
		(institution_to_roles || []).map do |instid, roles|
			a = Affiliation.new(user_id: user.id, institution_id: instid, roles: roles)
			a.save
		end
	end
	
end