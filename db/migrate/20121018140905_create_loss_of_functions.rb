class CreateLossOfFunctions < ActiveRecord::Migration
  def change
    create_table :loss_of_functions do |t|
      t.string :sift
      t.string :polyphen
      t.string :condel

      t.timestamps
    end
    
    #create_table :variation_annotation_has_loss_of_function do |t|
		#	t.references :variation_annotation
		#	t.references :loss_of_function
		#end
		#add_index :variation_annotation_has_loss_of_function, :variation_annotation_id
		#add_index :variation_annotation_has_loss_of_function, :loss_of_function_id
  end
end
