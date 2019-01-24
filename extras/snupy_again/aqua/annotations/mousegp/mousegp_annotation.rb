# == Description
# Performs annotation using Mousegp

class MousegpAnnotation < Annotation
	
	# If the initilizer is overwritten a call to super is neccessary to setup the VCFHEADER variable to parse a Vcf file.
	def initialize(opts = {})
		super # neccessary to setup @VCFHEADER
		## check setup vep file
	end
	
	def self.ready?
		ready = super
		ready
	end
	
	# Executes annotation
	# == Parameters
	# [file_path] file to the minimal vcf/csv file containing missing variants
	# [input_vcf] VcfFile objects with the current vcf files
	def perform_annotation(file_path, input_vcf)
		output_file = nil
		begin
			species      = input_vcf.organism.name
			species_name = species.downcase.gsub(" ", "_")
			log_file       = File.join(Rails.root, "log", "mousegp_annotation.log")
			error_log_file = File.join(Rails.root, "log", "mousegp_annotation.error.log")
			output_file = do_annotation(file_path)
			if output_file.nil?
				raise Exception.new("Annotatil failed.")
			end
			d "Annotation finished at #{Time.now}"
		rescue => e
			self.class.log_fatal("#{e.message}: #{e.backtrace.pretty_print_inspect}")
			raise
		end
		return output_file
	end
	
	def do_annotation(file)
		# do everything you need to do to perform the annotaiton
		outfile = "#{file}.output"
		success = false
		return nil if !success
		outfile
	end
	
	# Executes storing procedures
	# == Parameters
	# [result] the result output file as returned by perform_annotation
	# [vcf] VcfFile objects with the current vcf file
	def store(result, vcf)
		raise "Not implemented"
	end
	
	register_tool name:               :mousegp,
				  label:              "mousegp",
				  input:              :vcf, # can be vcf or csv
				  output:             :vcf, # can be anything really, it is mostly used if your tool returns different outpuf formats
				  supports:           [:snp, :indel],
				  organism:           [organisms(:human), organisms(:mouse)], # other organisms can be added here
				  model:              [Mousegp],
				  include_regulatory: false # add additional configurgation


end