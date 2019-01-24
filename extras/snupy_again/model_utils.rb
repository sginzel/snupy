module SnupyAgain
# == Description
# Contains functions that can be applied to models.
	module ModelUtils
		# == Description
		# This method can be used to make equal comparisons between two models. Two model instances are considerd to be equal when every attribute is equal except id, created_at and updated_at
		def == (other_model)
			attr_to_ignore = %w(id created_at updated_at)
			return false unless other_model.is_a?(ActiveRecord::Base)
			mymodel = self.class
			othermodel = other_model.class
			my_attr = mymodel.attribute_names.reject{|a| attr_to_ignore.include?(a)}.sort
			other_attr = othermodel.attribute_names.reject{|a| attr_to_ignore.include?(a)}.sort
			return false unless my_attr == other_attr
			return false if my_attr.any?{|a| self[a] != other_model[a]}
			return true
		end
	end
end