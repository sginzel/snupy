# == Description 
# A VariationCallTag is used to add generic additional Information to VariationCalls. 
# We call them tags. There is n x m relation between the VariationCallTag and 
# VariationCall, which is organized in the variation_call_has_variation_call_tag
# table. 
# == Attributes
# [tag_name] Name
# [tag_value] 
#  Tag Value, this is VARCHAR in the database and mustn't be longer 
#  than 256 with MySQL default
# [tag_type] This is used to group different tags
class VariationCallTag < ActiveRecord::Base
	has_and_belongs_to_many :variation_calls, join_table: :variation_call_has_variation_call_tag
  attr_accessible :tag_name, :tag_value, :tag_type
  
  AVAILABLE_NAME = %w(SOMATIC GERMLINE CANDIDATE POSITIVE_VALIDATION NEGATIVE_VALIDATION)
 	validates_inclusion_of :tag_name, :in => AVAILABLE_NAME
end
