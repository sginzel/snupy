class VcfFileClinvar < VcfFile
	extend ActiveSupport::DescendantsTracker

	def self.supports
		[:snp, :indel]
	end
	
	def validate_vcf_header(header)
		raise "VcfFile does not contain ClinVar source flag (source=ClinVar)." if !header.any?{|line| !line.downcase.index("##source=clinvar").nil? }
	end
	
	def validate_vcf_line(columns)
		# raise "Not enough columns to be a VarScan file. Somatic require 11 and trio require 12 columns." unless columns.size == 11 or columns.size == 12
	end
	
	def sanity_check_content(content)
		true
	end

	def get_variation_calls(sample_name, &block)
		raise "Cannot extract variation calls from Clinvar file"
	end

	# This skips records that have an alteration > 100 base pairs, because they are not of interest, nor can they be detected using WES
	def is_record_valid(record)
		record["alt"].split(",").all?{|alt| alt.size <= 100} &&
		record["ref"].size <= 100 &&
		((1..22).to_a + %w(X Y)).map(&:to_s).include?(record["chrom"].to_s)
	end
	
	def predict_tags_by_name()
		self.tags = []
		self.save
		self.tags
	end

end