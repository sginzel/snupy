class OmimMigration < ActiveRecord::Migration
	@@CONFIG          = YAML.load_file(File.join(Aqua.annotationdir ,"omim", "omim_config.yaml"))[Rails.env]
	@@GENEMAPTABLE     = "omim_genemap#{@@CONFIG["version"].to_s.gsub(".", "_")}s".to_sym # there is a pending s to be confirm with RAILS pluralized table form
	
	# create the table here
	def up
		
		#https://omim.org/help/faq
		create_table @@GENEMAPTABLE  do |t|
			t.string :phenotype # clean phenotype name, without classifiers
			t.string :phenotype_raw # raw omim phenotype name
			t.string :gene_name
			t.string :symbol # approved symbol
			t.string :entrezid # approved symbol
			t.string :ensembl_gene_id # approved symbol
			t.string :symbol_alias # aliases
			t.string :mgi_id # aliases
			t.string :mgi_symbol # aliases
			t.string :comments, size: 1024
			t.integer :gene_mim
			t.integer :phenotype_mim
			t.boolean :is_nondisease
			t.boolean :is_susceptible
			t.boolean :is_provisional
			t.boolean :map_wildtype  #(1)
			t.boolean :map_phenotype #(2)
			t.boolean :map_molecular_known #(3)
			t.boolean :map_chr_deldup #(4)
			t.boolean :link_autosomal # starting with 1, 2 or 6
			t.boolean :link_x # starting with 3
			t.boolean :link_y # starting with 4
			t.boolean :link_mitochondrial # starting with 5
			t.boolean :is_autosomal_recessive
			t.boolean :is_autosomal_dominant
			t.boolean :is_multifactorial
			t.boolean :is_isolated_cases
			t.boolean :is_digenic_recessive
			t.boolean :is_mitochondrial
			t.boolean :is_somatic_mutation
			t.boolean :is_somatic_mosaicism
			t.boolean :is_xlinked
			t.boolean :is_ylinked
			t.boolean :is_dominant
			t.boolean :is_recessive
			
		end
		
		add_index @@GENEMAPTABLE, :phenotype
		add_index @@GENEMAPTABLE, :phenotype_raw
		add_index @@GENEMAPTABLE, :gene_name
		add_index @@GENEMAPTABLE, :symbol
		add_index @@GENEMAPTABLE, :entrezid
		add_index @@GENEMAPTABLE, :ensembl_gene_id
		add_index @@GENEMAPTABLE, :symbol_alias
		add_index @@GENEMAPTABLE, :mgi_id
		add_index @@GENEMAPTABLE, :mgi_symbol
		add_index @@GENEMAPTABLE, :comments
		add_index @@GENEMAPTABLE, :gene_mim
        add_index @@GENEMAPTABLE, :phenotype_mim
		add_index @@GENEMAPTABLE, :is_nondisease
		add_index @@GENEMAPTABLE, :is_susceptible
		add_index @@GENEMAPTABLE, :is_provisional
		add_index @@GENEMAPTABLE, :map_wildtype
		add_index @@GENEMAPTABLE, :map_phenotype
		add_index @@GENEMAPTABLE, :map_molecular_known
		add_index @@GENEMAPTABLE, :map_chr_deldup
		add_index @@GENEMAPTABLE, :link_autosomal
		add_index @@GENEMAPTABLE, :link_x
		add_index @@GENEMAPTABLE, :link_y
		add_index @@GENEMAPTABLE, :link_mitochondrial
		add_index @@GENEMAPTABLE, :is_autosomal_recessive
		add_index @@GENEMAPTABLE, :is_autosomal_dominant
		add_index @@GENEMAPTABLE, :is_multifactorial
		add_index @@GENEMAPTABLE, :is_isolated_cases
		add_index @@GENEMAPTABLE, :is_digenic_recessive
		add_index @@GENEMAPTABLE, :is_mitochondrial
		add_index @@GENEMAPTABLE, :is_somatic_mutation
		add_index @@GENEMAPTABLE, :is_somatic_mosaicism
		add_index @@GENEMAPTABLE, :is_xlinked
		add_index @@GENEMAPTABLE, :is_ylinked
		add_index @@GENEMAPTABLE, :is_dominant
		add_index @@GENEMAPTABLE, :is_recessive

		puts "#{@@GENEMAPTABLE} for omim has been migrated."
		puts "In case you used scaffolding: Remember to activate your AQuA components setting activate: true".yellow
	end
	
	# destroy tables here
	def down
		drop_table @@GENEMAPTABLE
		puts "#{@@GENEMAPTABLE} for  omim  has been rolled back.".cyan
		puts "Remember to de-activate your AQuA components setting activate: false".red
	end

end