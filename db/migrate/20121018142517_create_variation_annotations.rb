class CreateVariationAnnotations < ActiveRecord::Migration
  def change
    create_table :variation_annotations do |t|
      t.references :variation, null: false
      t.references :genetic_element, null: false
      t.references :loss_of_function
      t.references :organism
      # t.references :consequence
      t.integer :cdna_position
      t.integer :cds_position
      t.integer :protein_position
      t.string :amino_acids
      t.string :codons
      t.string :existing_variation
      t.string :exon
      t.string :intron
      t.string :motif_name
      t.integer :motif_pos
      t.string :sv
      t.integer :distance
      t.string :canonical
      t.float :sift_score
      t.float :polyphen_score
      t.string :gmaf
      t.string :domains
      t.string :ccds
      t.string :hgvsc
      t.string :hgvsp
      t.float :blosum62
      t.text :downstreamprotein, limit: 4048
      t.integer :proteinlengthchange
      t.text :other_yaml, limit: 4048

      t.timestamps
    end
    add_index :variation_annotations, :variation_id
    add_index :variation_annotations, :genetic_element_id
    add_index :variation_annotations, :loss_of_function_id
  end
end
