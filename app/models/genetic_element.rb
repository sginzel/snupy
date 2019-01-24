# == Description
# A genetic element holds identifiers for a genetic element. So far it reflects the ensembl gene and protein identifiers as well as the hgnc symbol
# It is linked to a prediction that is stored in the Vep object.
# == Attributes
# [ensembl_gene_id] ensembl gene id
# [ensembl_feature_id] Usually a ENST-ID or a ENSR-ID
# [ensembl_feature_type] Transcript and region are pretty common here
# [ensp] ensembl protein id
# [hgnc] hgnc symbol
class GeneticElement < ActiveRecord::Base
	has_many :variation_annotations, inverse_of: :genetic_element
	has_many :variations, through: :variation_annotations, inverse_of: :genetic_elements
  has_many :samples, through: :variation_annotations

	belongs_to :organism, inverse_of: :genetic_elements

  has_many :experiments, through: :samples

  attr_accessible :ensembl_gene_id, :ensembl_feature_id, :ensembl_feature_type, :ensp, :hgnc, :organism_id
	
	# == Description
	# This Validator checks if a symbol is present before saving. 
	# If no symbol is present but an ensembl_gene_id we try to determine that 
	# from the database. This is especially useful for mus musculus entries for
	# which VEP does not yield a gene symbol.
	class GeneticElementNeedsSymbolValidator < ActiveModel::Validator
		def validate(record)
			if record.hgnc.nil? then
				if !record.ensembl_gene_id.nil? then
					record.hgnc = record.ensembl_to_symbol[record.ensembl_gene_id].first
					# record.hgnc = record.ensembl_gene_id if record.hgnc.nil? 
					if !record.hgnc.nil?
						Rails.logger.info "[GENETIC_ELEMENT] determined symbol '#{record.hgnc}' from '#{record.ensembl_gene_id}'"
					else
						Rails.logger.warn "[GENETIC_ELEMENT] No symbol found for '#{record.ensembl_gene_id}'"
					end
				end
			end
		end
	end
	
	validates_with GeneticElementNeedsSymbolValidator
	
	def ensembl_to_symbol()
		GeneticElement.ensembl_to_symbol(self.ensembl_gene_id, self.organism)
	end
  
	def symbol_to_ensembl()
		GeneticElement.symbol_to_ensembl(self.ensembl_gene_id, self.organism)
	end

	# find mutations in a set of given genetic elements that have a fatal consequence for the sequence
	def self.get_varcalls(genetic_elements, smplids = Sample.pluck(:id), consequences = Consequence::FATAL)
		organism = Organism.joins(:genetic_elements).where("genetic_elements.id" => genetic_elements).uniq.to_a
		if organism.count != 1 then
			d organism
			raise "The genetic Elements you request do not belong to the same organism."
		end

		organism = organism.first
		
		VariationCall.joins(
											:sample, 
											{
												variation: [
													:region, 
													:alteration, 
													{
														variation_annotations: [:genetic_element, :consequences]
													}
												]
											}
										).where("genetic_elements.id" => genetic_elements)
										.where("samples.id" => smplids)
										.where("consequences.consequence" => consequences)
										.where("variation_annotations.organism_id" => organism)
	end

  # Determines symbols from ensembl gene ids
  # 
  # * Input: Ensembl Gene ID
  # * Output: {"ENSG1" => ["SYMBOL1", "SYMBOL2"]}
  def self.ensembl_to_symbol(ensids, organism = Organism.find_by_name("homo sapiens"))
  	return GeneticElement.ensembl_to_symbol([ensids], organism) unless ensids.is_a?(Array)
  	ensembldb = organism.name.gsub(" ", "_") 
  	if (ensembldb == "homo_sapiens") then
  		ensembldb = "homo_sapiens_core_70_37"
  	else
  		ensembldb = "mus_musculus_70_38"
  	end
  	symbols = Hash[ensids.map{|e| [e, []]}]
  	ActiveRecord::Base.connection.execute(
  		sprintf("SELECT
			        display_label as symbol,
			        stable_id as ensembl_gene_id
				    FROM %s.xref
				    INNER JOIN %s.object_xref ox USING (xref_id)
				    INNER JOIN %s.external_db USING (external_db_id)
				    INNER JOIN %s.gene ON (%s.gene.gene_id = ox.ensembl_id)
				    WHERE external_db_id IN (1100, 1400, 3300) AND stable_id IN ( %s )
				    ORDER BY priority
			", ensembldb, ensembldb, ensembldb, ensembldb, ensembldb, ensids.map{|e| "'#{e}'"}.join(","))
		).each(as: :hash) do |rec|
			next if symbols[rec["ensembl_gene_id"]].nil?
			# symbols[rec["ensembl_gene_id"]] = [] if symbols[rec["ensembl_gene_id"]].nil?
			symbols[rec["ensembl_gene_id"]] << rec["symbol"]
		end
		## make arrays uniq
		symbols.keys.each do |ensg|
			if !symbols[ensg].nil? then
				symbols[ensg].uniq!
			end
		end
		symbols
  end
  
  def self.symbol_to_ensembl(symbols, organism = Organism.find_by_name("homo sapiens"))
  	return GeneticElement.symbol_to_ensembl([symbols], organism) unless symbols.is_a?(Array)
  	ensids = Hash[symbols.map{|s| [s, []]}]
  	ensembldb = organism.name.gsub(" ", "_") 
  	if (ensembldb == "homo_sapiens") then
  		ensembldb = "homo_sapiens_core_70_37"
  	else
  		ensembldb = "mus_musculus_70_38"
  	end
  	ActiveRecord::Base.connection.execute(
  		sprintf("SELECT
			        display_label as symbol,
			        stable_id as ensembl_gene_id
				    FROM %s.xref
				    INNER JOIN %s.object_xref ox USING (xref_id)
				    INNER JOIN %s.external_db USING (external_db_id)
				    INNER JOIN %s.gene ON (%s.gene.gene_id = ox.ensembl_id)
				    WHERE external_db_id IN (1100, 1400, 3300) AND display_label IN ( %s )
				    ORDER BY priority
			", ensembldb, ensembldb, ensembldb, ensembldb, ensembldb, symbols.map{|s| "'#{s}'"}.join(","))
		).each(as: :hash) do |rec|
			next if ensids[rec["symbol"]].nil?
			# ensids[rec["symbol"]] = [] if ensids[rec["symbol"]].nil?
			ensids[rec["symbol"]] << rec["ensembl_gene_id"]
		end
		## make arrays uniq
		ensids.keys.each do |symbol|
			if !ensids[symbol].nil? then
				ensids[symbol].uniq!
			end
		end
		ensids
  end
  
end
