class CreateConsequences < ActiveRecord::Migration
  def change
    create_table :consequences do |t|
      t.string :consequence

      t.timestamps
    end
    
    create_table :variation_annotation_has_consequence do |t|
			t.references :variation_annotation
			t.references :consequence
		end
    add_index :variation_annotation_has_consequence, :variation_annotation_id, name: :va_has_consequence_va_id
    add_index :variation_annotation_has_consequence, :consequence_id, name: :va_has_consequence_cons_id
  end
end
