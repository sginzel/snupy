# == Description 
# A VariationTag is used to add generic additional Information to Variations. 
# We call them tags. There is n x m relation between the VariationTag and 
# Variation, which is organized in the variation_has_variation_tag table.
# == Attributes
# [tag_name] Name
# [tag_value] 
#  Tag Value, this is VARCHAR in the database and mustn't be longer 
#  than 256 with MySQL default
# [tag_type] This is used to group different tags
class VariationTag < ActiveRecord::Base
	has_and_belongs_to_many :variations, join_table: :variation_has_variation_tag
  attr_accessible :tag_name, :tag_value, :tag_type
  
  AVAILABLE_NAME = %w()
 	validates_inclusion_of :tag_name, :in => AVAILABLE_NAME
end
