class AddUniqConstraintToAlterationAndRegion < ActiveRecord::Migration
	
	def up
		# add_index :alterations, [:ref, :alt, :alttype], :unique => true, :name => 'unique_field_combo'
  	# http://bugs.mysql.com/bug.php?id=6604
  	# ref and alt are long varchars, so we cant create a full index, because of
  	# the engine limitations
  	ActiveRecord::Base.connection.execute("ALTER TABLE `#{Alteration.table_name}` ADD UNIQUE INDEX `unique_field_combo_alteration`( ref(250), alt(250), alttype(5));")
  	add_index :regions, [:name, :start, :stop, :coord_system], :unique => true, :name => 'unique_field_combo_region'
	end
	
	def down
		ActiveRecord::Base.connection.execute("ALTER TABLE `#{Alteration.table_name}` DROP INDEX `unique_field_combo_alteration`")
		remove_index :regions, name: 'unique_field_combo_region'
	end
	
end
