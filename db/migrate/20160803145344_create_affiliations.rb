class CreateAffiliations < ActiveRecord::Migration
	def up
		create_table :affiliations do |t|
			t.references :user, null: false
			t.references :institution, null: false
			t.string :roles
		end
		add_index :affiliations, [:user_id, :institution_id]
		add_index :affiliations, :roles
		
		# TODO we shoudl remove the institution_has_user table because its not needed anymore.
		User.all.each do |u|
			uinst = ActiveRecord::Base.connection.exec_query(%Q(
				SELECT * FROM institution_has_users WHERE user_id = #{u.id}
			)).to_hash
			roles = [:user]
			roles = [:data_manager, :research_manager, :user] if u.is_admin?
			uinst.each do |uinstpair|
				aff = Affiliation.create({
					user_id: u.id,
					institution_id: uinstpair["institution_id"],
					roles: roles
				})
				aff.save
			end
		end
	end
	
	def down
		drop_table :affiliations
	end
	
end
