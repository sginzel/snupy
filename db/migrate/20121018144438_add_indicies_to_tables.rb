class AddIndiciesToTables < ActiveRecord::Migration
  def change
  	## experiment
  	# add_index :experiments, :institution ## not neccessary because we referenced it
  	
  	## vcf file
  	add_index :vcf_files, :sample_names
  	add_index :vcf_files, :status
  	
  	## sample
  	add_index :samples, :name
  	add_index :samples, :patient
  	add_index :sample_tags, :tag_name
  	# add_index :sample_tag, :tag_value # sample_tag.tag_value is a text and thus cannot be indexed
  	
  	## region
  	add_index :regions, :name
  	add_index :regions, :start
  	add_index :regions, :stop
  	add_index :regions, :coord_system
  	
  	## alteration
  	add_index :alterations, :ref
  	add_index :alterations, :alt
  	add_index :alterations, :alttype
  	
  	## variation
  	add_index :variation_tags, :tag_name
  	add_index :variation_tags, :tag_value
  	
  	## variation_call
  	add_index :variation_calls, :qual
  	add_index :variation_calls, :filter
  	add_index :variation_calls, :gt
  	add_index :variation_calls, :ps
  	add_index :variation_calls, :dp
  	add_index :variation_calls, :gl
  	add_index :variation_calls, :gq
  	add_index :variation_call_tags, :tag_name
  	add_index :variation_call_tags, :tag_value
  	
  	## genetic element
  	add_index :genetic_elements, :ensembl_gene_id
  	add_index :genetic_elements, :ensembl_feature_id
  	add_index :genetic_elements, :ensembl_feature_type
  	add_index :genetic_elements, :hgnc
  	add_index :genetic_elements, :ensp
  	
  	## loss of function
  	add_index :loss_of_functions, :sift
  	add_index :loss_of_functions, :polyphen
  	add_index :loss_of_functions, :condel
  	
  	## consequence
  	add_index :consequences, :consequence
  	
  	## vep
  	add_index :variation_annotations, :codons
  	add_index :variation_annotations, :existing_variation
  	add_index :variation_annotations, :exon
  	add_index :variation_annotations, :intron
  	add_index :variation_annotations, :motif_name
  	add_index :variation_annotations, :sv
  	add_index :variation_annotations, :canonical
  	add_index :variation_annotations, :gmaf
  	add_index :variation_annotations, :domains
  	add_index :variation_annotations, :blosum62
  	add_index :variation_annotations, :proteinlengthchange
  	
  end
end
