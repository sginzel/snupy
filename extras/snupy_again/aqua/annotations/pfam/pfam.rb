class Pfam < ActiveRecord::Base
	
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
	attr_accessible :variation_id,
					:organism_id
	
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