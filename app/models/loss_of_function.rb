# == Description
# Hold information about loss of function prediction from 3 tools
# TODO: Set up relationship in this model
# == Attributes
# [condel] Condel prediction - without scores
# [polyphen] polyphen prediction - without scores
# [sift] SIFT prediction - without scores
class LossOfFunction < ActiveRecord::Base
	# has_and_belongs_to_many :variation_annotations, join_table: :variation_annotation_has_loss_of_function# , inverse_of: :consequences
	has_many :variation_annotations, inverse_of: :loss_of_function
  attr_accessible :condel, :polyphen, :sift
end
