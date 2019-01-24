# == Description
# A User has access to different Experiments that he can create himself. 
# The User-Authentification is done through the HTTP-Authentification, 
# so you have to setup .htaccess access to you website. The default User is
# development who also has admin priviledges and can create new users.
# TODO: Integrate a better User management.
# == Attributes
# [email] e-mail
# [full_name] full name
# [is_admin] TRUE/FALSE if the user has admin priviledges. This lets him manage other users, institutions and datasets.
# [name] username (short form)
class User < ActiveRecord::Base
	has_and_belongs_to_many :experiments, join_table: :experiment_has_user
	# with the new sample annotation schema this relationship is to be ignored
	has_and_belongs_to_many :samples, join_table: :sample_has_users
	has_and_belongs_to_many :generic_lists, join_table: :generic_list_has_users
	# has_and_belongs_to_many :institutions, join_table: :institution_has_users
	has_many :affiliations, dependent: :destroy 
	has_many :institutions, through: :affiliations
	has_many :collegues, through: :institutions, class_name: "User", source: :users
	# has_many :entity_groups, through: :institutions
	# we link each user explicitly with an entity group.
	# This way we can share a group with someone from another institution without him being able to modify it
	has_and_belongs_to_many :entity_groups, join_table: :user_has_entity_groups
	has_many :entities, through: :entity_groups
	has_many :specimen_probes, through: :entities, class_name: "SpecimenProbe"
	# has_many :samples, through: :specimen_probes
	
	# has_many :vcf_files, readonly: true, through: :samples 
	# users should only be able to access VCF data if the are admin or have manager roles in the instituion the vcf belongs to.
	has_many :vcf_files, readonly: true, through: :institutions, :conditions => Proc.new { %Q{
		roles LIKE '%_manager%' OR #{id} IN (
			SELECT id FROM users WHERE is_admin = 1
		)
	}}
	
	has_many :variations, through: :samples, inverse_of: :users
	has_many :variation_calls, through: :samples, inverse_of: :users
	
	has_one :api_key

	has_many :long_jobs, through: :experiments, :conditions => Proc.new { %Q{long_jobs.user = '#{name}'}}

	attr_accessible :email, :full_name, :is_admin, :name
	
	validates :name, presence: true, uniqueness: true
	before_destroy :destroy_has_and_belongs_to_many_relations
	
	def destroy_has_and_belongs_to_many_relations
		# samples are now linked to a user via their entity groups. 
		# self.samples = []
		self.experiments = []
		self.generic_lists = []
		self.institutions = []
	end
	
	# returns a ActiveRecord::Relation which can be used to query the data
	def accessible_models(mdl, required_roles, include_direct_access = true)
		required_roles = Hash[required_roles.map{|x| [x, true]}]
		# check if association to institution and affiliations exists
		instassoc = (Aqua.find_association(mdl, :institution) || Aqua.find_association(mdl, :institutions))
		raise "accessible model requires association to institution" if instassoc.nil?
		# affiassoc = Aqua.find_association(mdl, :affiliations)
		
		mdltable = mdl.table_name
		assoc = Aqua.find_association(self.class, mdl)
		raise "Association not found" if assoc.nil?
		idsmethod = (assoc.name.to_s.singularize + "_ids").to_sym
		raise "Association derived access not found but required" if !respond_to?(idsmethod) && include_direct_access
		if is_admin
			ret = mdl.scoped #.joins(:institution)#.includes(:institution).where("1 = 1")
		else
			insts = roles.select{|institution, roles|
				roles.any?{|r| required_roles[r]}
			}
			if insts.nil? then # user does not meet the requirements in any institution
				return mdl.where("1 = 0")
			else
				insts = insts.keys
			end
			direct_accessible_ids = []
			direct_accessible_ids = send(idsmethod) if include_direct_access
			cond = []
			# we allow access to samples either by institution or by explicit permission - so a user doesnt have to be part of an institution, if he is granted direct access
			cond << "institutions.id IN (#{insts.map(&:id).join(",")})" if insts.size > 0
			cond << "#{mdltable}.#{mdl.primary_key} IN (#{direct_accessible_ids.join(",")})" if direct_accessible_ids.size > 0
			if cond.size > 0 
				if (Aqua.find_association(mdl, :institution)) then
					retids = mdl.joins(:institution).where(cond.join(" OR ")).pluck("#{mdltable}.#{mdl.primary_key}")
				elsif Aqua.find_association(mdl, :institutions) then
					retids = mdl.joins(:institutions).where(cond.join(" OR ")).pluck("#{mdltable}.#{mdl.primary_key}")
				else
					raise "Association between #{mdl} and Institution not found. Make sure an 'institution' or 'institutions' association is defined"
				end
				ret = mdl.where("#{mdltable}.#{mdl.primary_key}" => retids.uniq)
							# .includes(:institution) # when there is no includes the returned records will be read only
			else
				ret = mdl.where("1 = 0") # this is the best way to have a good empty relation. Rails 4 provides .none which would be nicer to use.
			end
		end
		ret
	end
	
	def can_see?(ids, mdl = (ids.is_a?(Array))?(ids.first.class):(ids.class))
		able_to?(:view, mdl, ids)
	end
	
	def can_review?(ids, mdl = (ids.is_a?(Array))?(ids.first.class):(ids.class))
		able_to?(:review, mdl, ids)
	end
	
	def can_edit?(ids, mdl = (ids.is_a?(Array))?(ids.first.class):(ids.class))
		able_to?(:edit, mdl, ids)
	end

	def owns?(ids, mdl = (ids.is_a?(Array))?(ids.first.class):(ids.class))
		able_to?(:own, mdl, ids)
	end
	
	def able_to?(action, mdl, ids = nil)
		action = action.to_s.downcase.to_sym
		if action == :visible or action == :see or action == :view then
			canids = visible(mdl).pluck("#{mdl.table_name}.#{mdl.primary_key}").sort
		elsif action == :editable or action == :edit or action == :modify or action == :manage then
			canids = editable(mdl).pluck("#{mdl.table_name}.#{mdl.primary_key}").sort
		elsif action == :review or action == :filter then
			canids = reviewable(mdl).pluck("#{mdl.table_name}.#{mdl.primary_key}").sort
		elsif action == :owns or action == :belongs or action == :own then
			canids = owned(mdl).pluck("#{mdl.table_name}.#{mdl.primary_key}").sort
		end
		return canids if ids.nil?
		ids = [ids] unless ids.is_a?(Array)
		ids = ids.map{|obj| (obj.is_a?(ActiveRecord::Base))?(obj.id):(obj)}
		ids.all?{|id| canids.include?(id)}
	end
	
	# gives you objects that are directly associated to you
	# or which you can access indirectly because you have access to it
	def owned(mdl)
		accessible_models(mdl, [], true)
	end
	
	# visible and reviewable are equal now that we have an advanced query schema
	def visible(mdl)
		# accessible_models(mdl, ["user", "research_manager", "data_manager"], true)
		accessible_models(mdl, ["user", "research_manager", "data_manager"], true)
	end
	
	# to view an object you have to be either a data or a research manager or be linked with it directly
	def reviewable(mdl)
		accessible_models(mdl, ["research_manager", "data_manager"], true)
		# visible(mdl)
	end
	
	# just the fact that you are linked as a user of an object doesnt give you the right to edit it
	# well it kind of should, because what is the point then?
	# Only data managers should be able to modify datasets.
	# If a direct association is available the datasets through the direct association need to be associated to the same
	# instition as the user. Otherwise it allows external users to edit a dataset.
	def editable(mdl)
		ret = accessible_models(mdl, ["data_manager"], true)
		if (Aqua.find_association(mdl, :institution)) then
			ret = ret.joins(:institution).where("institutions.id" => self.institutions)
		else Aqua.find_association(mdl, :institutions)
		ret = ret.joins(:institutions).where("institutions.id" => self.institutions)
		end
		ret
	end
	
	def is_admin?()
		read_attribute(:is_admin)
	end
	
	def roles(institution = nil)
		@_institution_cache = nil
		@_institution_cache = {} if @_institution_cache.nil? # using a cache might be not such a good idea at some point...
		return @_institution_cache[institution] unless @_institution_cache[institution].nil? 
		if institution.nil? then
			ret = Hash.new()
			ret.default = []
			institutions.each do |i|
				ret[i] = roles(i)
			end
			return ret
		else
			# aff = affiliations.where(institution_id: institution.id).first
			aff = affiliations.select{|a| a.institution_id == institution.id}.first
			return [] if aff.nil?
			ret = aff.roles.values
			@_institution_cache[institution] = ret
			return ret
		end
	end
	
	def is_data_manager_at?(institution)
		return false if institution.nil?
		# User.joins(:affiliations).where("affiliations.institution_id" => institution.id)
		roles(institution).include?("data_manager")
	end
	
	def is_research_manager_at?(institution)
		return false if institution.nil?
		roles(institution).include?("research_manager")
	end
	
	def is_user_at?(institution)
		return false if institution.nil?
		roles(institution).include?("user")
	end
	
	def is_data_manager?()
		roles.any?{|inst, roles| roles.include?("data_manager")} || is_admin?
	end
	
	def is_research_manager?()
		roles.any?{|inst, roles| roles.include?("research_manager")}
	end
	
	def is_user?()
		roles.any?{|inst, roles| roles.include?("user")} || is_research_manager? || is_data_manager?
	end
	
	def jobs
		LongJob.where("user = ? OR user = ?", self.name, self.full_name)
	end
	
	def has_api?
		return !self.api.nil?
	end
	
	# TODO Refactor this, so it is treated like samples are.
	def generic_gene_lists()
		return GenericGeneList.where(type: "GenericGeneList") if self.is_admin
		return generic_lists().where(type: "GenericGeneList")
	end
	
	def generic_region_lists()
		return GenericRegionList.where(type: "GenericRegionList") if self.is_admin
		return generic_lists().where(type: "GenericRegionList")
	end
	
end
