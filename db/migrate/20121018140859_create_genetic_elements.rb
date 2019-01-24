class CreateGeneticElements < ActiveRecord::Migration
  def change
    create_table :genetic_elements do |t|
      t.string :ensembl_gene_id #, null: false
      t.string :ensembl_feature_id
      t.string :ensembl_feature_type
      t.string :hgnc
      t.string :ensp

      t.timestamps
    end
  end
end
