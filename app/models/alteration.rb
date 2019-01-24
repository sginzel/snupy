##
# == Description 
# An Alteration describes a change on a genomic level.
# == Fields
# [ref] Contains the reference sequence and must not be empty
# [alt] Contains the alternative/observed sequence at a given Region
# [type] Must be any of: :snp, :indel, :cnv, :sv
class Alteration < ActiveRecord::Base
  
  include SnupyAgain::ModelUtils
  
  has_many :variations, inverse_of: :alteration, dependent: :destroy
  #has_many :variation_annotations, through: :variations, inverse_of: :alteration
  
  attr_accessible :alt, :ref, :alttype
  
  validates_inclusion_of :alttype, :in => [:snp, :indel, :cnv, :sv]

	def alttype
		read_attribute(:alttype).to_sym
	end

	def alttype= (value)
		write_attribute(:alttype, value.to_s)
	end
	
	def self.determine_alttype(ref, alt)
		alttype = :snp
		alttype = :indel if alt.length > 1 or ref.length > 1
		alttype = :cnv if alt =~ /^<CNV.*>$/
		alttype = :sv if alt =~ /^<(DEL|INS|INV|DUP).*>$/
		alttype 
	end
	
	def <=> (other_alteration)
		return "#{self.ref}:#{self.alt}" <=> "#{other_alteration.ref}:#{other_alteration.alt}"
	end
	
end
