class MousegpMigration < ActiveRecord::Migration
	@@MGPCONFIG = YAML.load_file(File.join(Rails.root, "extras", "snupy_again", "aqua", "annotations" ,"mousegp", "mousegp.yaml"))[Rails.env]
	@@MGPTABLENAME = "mgp_v#{@@MGPCONFIG["version"].to_s.gsub(".", "_")}s".to_sym # there is a pending s to be confirm with RAILS pluralized table form

	# create the table here
	def up
		create_table @@MGPTABLENAME do |t|
			t.references :variation, null: false
			t.references :organism, null: false
			t.string :ref
			t.string :alt_consensus
			t.string :alt_consensus_consequence
			t.float  :alt_consensus_freq
			t.integer :ref_allele_count, limit: 1
			t.integer :alt_allele_count, limit: 1
			# encoding of genotypes:
			# Capital letters: homozygous mutation (contributes 2 towards consensus & allele count)
			# small caps: heterozygous mutation (contributes 1 towards consensus & allele count)
			# + : Insertion
			# - : deletion
			# NULL: reference
			# "X": No data available
			t.string :"129P2_OlaHsd", default: nil, limit: 1
			t.string :"129S1_SvImJ", default: nil, limit: 1
			t.string :"129S5SvEvBrd", default: nil, limit: 1
			t.string :A_J, default: nil, limit: 1
			t.string :AKR_J, default: nil, limit: 1
			t.string :BALB_cJ, default: nil, limit: 1
			t.string :BTBR, default: nil, limit: 1
			t.string :BUB_BnJ, default: nil, limit: 1
			t.string :C3H_HeH, default: nil, limit: 1
			t.string :C3H_HeJ, default: nil, limit: 1
			t.string :C57BL_10J, default: nil, limit: 1
			t.string :C57BL_6NJ, default: nil, limit: 1
			t.string :C57BR_cdJ, default: nil, limit: 1
			t.string :C57L_J, default: nil, limit: 1
			t.string :C58_J, default: nil, limit: 1
			t.string :CAST_EiJ, default: nil, limit: 1
			t.string :CBA_J, default: nil, limit: 1
			t.string :DBA_1J, default: nil, limit: 1
			t.string :DBA_2J, default: nil, limit: 1
			t.string :FVB_NJ, default: nil, limit: 1
			t.string :I_LnJ, default: nil, limit: 1
			t.string :KK_HiJ, default: nil, limit: 1
			t.string :LEWES_EiJ, default: nil, limit: 1
			t.string :LP_J, default: nil, limit: 1
			t.string :MOLF_EiJ, default: nil, limit: 1
			t.string :NOD_ShiLtJ, default: nil, limit: 1
			t.string :NZB_B1NJ, default: nil, limit: 1
			t.string :NZO_HlLtJ, default: nil, limit: 1
			t.string :NZW_LacJ, default: nil, limit: 1
			t.string :PWK_PhJ, default: nil, limit: 1
			t.string :RF_J, default: nil, limit: 1
			t.string :SEA_GnJ, default: nil, limit: 1
			t.string :SPRET_EiJ, default: nil, limit: 1
			t.string :ST_bJ, default: nil, limit: 1
			t.string :WSB_EiJ, default: nil, limit: 1
			t.string :ZALENDE_EiJ, default: nil, limit: 1
			t.timestamps
		end
		
		add_index @@MGPTABLENAME, :variation_id
		add_index @@MGPTABLENAME, :organism_id
		add_index @@MGPTABLENAME, :"129P2_OlaHsd"
		add_index @@MGPTABLENAME, :"129S1_SvImJ"
		add_index @@MGPTABLENAME, :"129S5SvEvBrd"
		add_index @@MGPTABLENAME, :A_J
		add_index @@MGPTABLENAME, :AKR_J
		add_index @@MGPTABLENAME, :BALB_cJ
		add_index @@MGPTABLENAME, :BTBR
		add_index @@MGPTABLENAME, :BUB_BnJ
		add_index @@MGPTABLENAME, :C3H_HeH
		add_index @@MGPTABLENAME, :C3H_HeJ
		add_index @@MGPTABLENAME, :C57BL_10J
		add_index @@MGPTABLENAME, :C57BL_6NJ
		add_index @@MGPTABLENAME, :C57BR_cdJ
		add_index @@MGPTABLENAME, :C57L_J
		add_index @@MGPTABLENAME, :C58_J
		add_index @@MGPTABLENAME, :CAST_EiJ
		add_index @@MGPTABLENAME, :CBA_J
		add_index @@MGPTABLENAME, :DBA_1J
		add_index @@MGPTABLENAME, :DBA_2J
		add_index @@MGPTABLENAME, :FVB_NJ
		add_index @@MGPTABLENAME, :I_LnJ
		add_index @@MGPTABLENAME, :KK_HiJ
		add_index @@MGPTABLENAME, :LEWES_EiJ
		add_index @@MGPTABLENAME, :LP_J
		add_index @@MGPTABLENAME, :MOLF_EiJ
		add_index @@MGPTABLENAME, :NOD_ShiLtJ
		add_index @@MGPTABLENAME, :NZB_B1NJ
		add_index @@MGPTABLENAME, :NZO_HlLtJ
		add_index @@MGPTABLENAME, :NZW_LacJ
		add_index @@MGPTABLENAME, :PWK_PhJ
		add_index @@MGPTABLENAME, :RF_J
		add_index @@MGPTABLENAME, :SEA_GnJ
		add_index @@MGPTABLENAME, :SPRET_EiJ
		add_index @@MGPTABLENAME, :ST_bJ
		add_index @@MGPTABLENAME, :WSB_EiJ
		add_index @@MGPTABLENAME, :ZALENDE_EiJ
		
	end
	
	# destroy tables here
	def down
		drop_table @@MGPTABLENAME
	end

end