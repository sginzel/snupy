class Statistic < ActiveRecord::Base
  include SnupyAgain::Utils
  
  AVAILABLE_PLOTS = %w(table series_wo_points series scatter pie barchart boxplot hist)
  
  attr_accessible :name, :value, :resource, :record_id, :plotstyle
 	validates_inclusion_of :plotstyle, :in => AVAILABLE_PLOTS
  
  
  def value()
  	data = read_attribute(:value)
  	return nil if data.nil?
  	unzip(data)
  end
  
  def value=(newval)
  	if !newval.nil? then
  		write_attribute(:value, zip(newval))
  	else
  		write_attribute(:value, nil)
  	end
  end
  
end
