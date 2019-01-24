class Mousegp < ActiveRecord::Base

	@@MGPCONFIG = YAML.load_file(File.join(Rails.root, "extras", "snupy_again", "aqua", "annotations" ,"mousegp", "mousegp.yaml"))[Rails.env]
	@@MGPTABLENAME = "mgp_v#{@@MGPCONFIG["version"].to_s.gsub(".", "_")}s".to_sym # there is a pending s to be confirm with RAILS pluralized table form
	self.table_name = @@MGPTABLENAME

	# optional, but handy associations
	belongs_to :variation
	belongs_to :organism
	has_one :alteration, through: :variation
	has_one :region, through: :variation
	has_many :variation_calls, foreign_key: :variation_id, primary_key: :variation_id
	has_many :samples, through: :variation_calls
	has_many :users, through: :samples
	has_many :experiments, through: :samples
	
	# list all attributes here to mass-assign them
	# encoding of genotypes:
	# Capital letters: homozygous mutation (contributes 2 towards consensus & allele count)
	# small caps: heterozygous mutation (contributes 1 towards consensus & allele count)
	# + : Insertion
	# - : deletion
	# NULL: reference
	# "X": No data available
	attr_accessible :variation_id,
					:organism_id,
					:ref,
					:alt_consensus,
					:alt_consensus_consequence,
					:alt_consensus_freq,
					:ref_allele_count,
					:alt_allele_count,
					:"129P2_OlaHsd",
					:"129S1_SvImJ",
					:"129S5SvEvBrd",
					:A_J,
					:AKR_J,
					:BALB_cJ,
					:BTBR,
					:BUB_BnJ,
					:C3H_HeH,
					:C3H_HeJ,
					:C57BL_10J,
					:C57BL_6NJ,
					:C57BR_cdJ,
					:C57L_J,
					:C58_J,
					:CAST_EiJ,
					:CBA_J,
					:DBA_1J,
					:DBA_2J,
					:FVB_NJ,
					:I_LnJ,
					:KK_HiJ,
					:LEWES_EiJ,
					:LP_J,
					:MOLF_EiJ,
					:NOD_ShiLtJ,
					:NZB_B1NJ,
					:NZO_HlLtJ,
					:NZW_LacJ,
					:PWK_PhJ,
					:RF_J,
					:SEA_GnJ,
					:SPRET_EiJ,
					:ST_bJ,
					:WSB_EiJ,
					:ZALENDE_EiJ,
	# optional method in case you want to do inheritance
	def self.aqua_table_alias
		self.table_name
	end
	
end

# Inheritance example - uses source as type column
#class Vep::Ensembl < Vep
#	self.inheritance_column   = 'source'
#	self.store_full_sti_class = false # if we don't do this ActiveRecord assumes the value to be Vep::Ensembl instead of Ensembl
#
#	has_many :ref_seq, :class_name => "Vep::RefSeq",
#			 :foreign_key          => "variation_id", conditions: proc {"organism_id = #{self.organism_id}"}
#	def self.aqua_table_alias
#		"vep_ensembls"
#	end
#
#end