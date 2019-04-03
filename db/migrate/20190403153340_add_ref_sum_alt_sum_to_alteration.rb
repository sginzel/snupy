# MD5sums for alt and ref allow uniquness indexes of constant size to be created.
# This is useful, because very large indels may have the same prefix and thus their uniquness collides
class AddRefSumAltSumToAlteration < ActiveRecord::Migration
	def up
		add_column Alteration.table_name, :refmd5, :string, null: false
		add_column Alteration.table_name, :altmd5, :string, null: false
		add_index Alteration.table_name, :refmd5, length: 32
		add_index Alteration.table_name, :altmd5, length: 32
		
		Alteration.update_all("refmd5 = MD5(ref), altmd5 = MD5(alt)")
		
		add_index Alteration.table_name, [:refmd5, :altmd5], unique: true
		ActiveRecord::Base.connection.execute("ALTER TABLE `#{Alteration.table_name}` DROP INDEX `unique_ref_alt_pairs`")
		
	end
	
	def down
		remove_index Alteration.table_name, [:refmd5, :altmd5]
		remove_column Alteration.table_name, :refmd5
		remove_column Alteration.table_name, :altmd5
		ActiveRecord::Base.connection.execute("ALTER TABLE `#{Alteration.table_name}` ADD UNIQUE INDEX `unique_ref_alt_pairs`( ref(250), alt(250), alttype(5));")
	end
end
