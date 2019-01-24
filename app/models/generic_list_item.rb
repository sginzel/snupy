# == Description
# This model contains items that belong to a GenericList model. Values are automatically stored in YAML format.
class GenericListItem < ActiveRecord::Base
  belongs_to :generic_list, inverse_of: :generic_list_items
  attr_accessible :value, :type
  
  def value()
  	ret = read_attribute(:value)
  	ret = YAML.load(ret) if ret != ""
  	ret
  end
  
  def value=(newvalue)
  	write_attribute(:value, newvalue.to_yaml)
  end
  
end
