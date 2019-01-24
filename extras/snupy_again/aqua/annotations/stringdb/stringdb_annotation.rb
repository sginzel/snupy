# == Description
# Does not perform any annotation

class StringdbAnnotation < Annotation
	
	register_tool name: :stringdb,
				  label: "StringDB v9",
				  input: nil,
				  output: nil,
				  supports: [:none],
				  organism: [organisms(:human), organisms(:mouse)],
				  model: [Stringdb],
				  requires: ['VepAnnotation']
	
	# Find the subset of varids that were annotated with tool
	def self.find_annotations(varids, organism_id)
		# TODO create association to variation id - maybe too complex, but hey...
		tool = self
		conf = tool.configuration
		themodel = self.model
		themodel.where(variation_id: varids, organism_id: organism_id)
	end
	
	# If the initilizer is overwritten a call to super is neccessary to setup the VCFHEADER variable to parse a Vcf file.
	def initialize(opts={})
		super # neccessary to setup @VCFHEADER
		begin
			d "STRINGDB Annotation module loaded!"
		end
	end
	
	def self.satisfied?()
		true
	end
	
	def self.ready?
		#return false if 1 == 1
		return true # TODO implement this
		satisfied = super
		satisfied && true
	end
	
	def perform_annotation(file_path, input_vcf)
		d "************ STRINGDB Annotation ***********"
		d "FOR : #{file_path}"
		d "Organism: #{input_vcf.organism.id} - #{input_vcf.organism.name}"
		d "IS NOT IMPLEMETED"
		return filepath
	end
	
	# re implemented version of store that relies mostly on multianno.csv
	# def store(result, vcf)
	def store(result, vcf)
		d "************ STRINGDB Storage ***********"
		d "FOR : #{result}"
		d "Organism: #{vcf.organism.id} - #{vcf.organism.name}"
		d "IS NOT IMPLEMETED"
		return true
	end
	
end