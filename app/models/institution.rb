# == Description
# An Institution has many Experiments and VcfFiles. It is used to group samples and restrict access
# when using results from other samples in the experiment query.
# == Attributes
# [contact] Institution contact
# [email] E-Mail adress to lookup
# [name] Name
# [phone] Phone number, not checked if valid number
class Institution < ActiveRecord::Base
	has_many :experiments, dependent: :destroy
	has_many :vcf_files, dependent: :nullify
	# has_many :users, through: :experiments, inverse_of: :institutions
	# has_and_belongs_to_many :users, join_table: :institution_has_users
	
	# has_many :samples, through: :vcf_files, uniq: true, inverse_of: :institution

	has_many :affiliations, inverse_of: :institution, dependent: :destroy
	has_many :users, through: :affiliations

	# has_and_belongs_to_many :entity_groups, join_table: :institution_has_entity_groups
	has_many :entity_groups
	has_many :entities, class_name: "Entity", through: :entity_groups
	has_many :specimen_probes, through: :entities
	has_many :samples, through: :specimen_probes

	attr_accessible :contact, :email, :name, :phone

	before_destroy :destroy_has_and_belongs_to_many_relations
	def destroy_has_and_belongs_to_many_relations
		self.users = []
		self.entity_groups = []
	end

	def roles(user = nil)
		if user.nil? then
			ret = Hash.new([])
			users.each do |u|
				ret[u] = roles(u)
			end
		return ret
		else
			aff = affiliations.where("user_id" => user.id).first
		return [] if aff.nil?
		return aff.roles.values
		end
	end

end
