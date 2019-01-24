class Cadd < ActiveRecord::Base
	extend SnupyAgain::AnnotationSummary
	
	@@CADDCONFIG = YAML.load_file(File.join(Rails.root, "extras", "snupy_again", "aqua", "annotations" ,"cadd", "cadd.yaml"))[Rails.env]
	@@CADDTABLENAME = "cadd#{@@CADDCONFIG["version"].to_s.gsub(".", "_")}s".to_sym # there is a pending s to be confirm with RAILS pluralized table form
	
	self.table_name = @@CADDTABLENAME #CaddAnnotation.config('table_name').to_sym # there is a pending s to be confirm with RAILS pluralized table form
	
	# optional, but handy associations
	belongs_to :variation
	belongs_to :organism
	has_one :alteration, through: :variation
	has_one :region, through: :variation
	has_many :variation_calls, foreign_key: :variation_id, primary_key: :variation_id
	has_many :samples, through: :variation_calls
	has_many :users, through: :samples
	has_many :experiments, through: :samples
	
	# list all attributes here to mass-assign them
	attr_accessible :variation_id,
					:organism_id,
	                :raw,
	                :phred
	
	# optional method in case you want to do inheritance
	def self.aqua_table_alias
		self.table_name
	end
	
	# quantile based summary of the Conservation, LOFP and Frequencies
	def summary(quantile_estimators)
		ret = {}
		summary = {
			cadd_q: [:phred]
		}
		summary.each do |category, attrs|
			ret[category] = attrs.map{|attr|
				qestimator = quantile_estimators[attr.to_s] || quantile_estimators[attr.to_sym]
				next if qestimator.nil?
				qestimator.estimate_quantile self[attr]
			}
		end
		ret
	end
	
end

# Inheritance example - uses source as type column
#class Vep::Ensembl < Vep
#	self.inheritance_column   = 'source'
#	self.store_full_sti_class = false # if we don't do this ActiveRecord assumes the value to be Vep::Ensembl instead of Ensembl
#
#	has_many :ref_seq, :class_name => "Vep::RefSeq",
#			 :foreign_key          => "variation_id", conditions: proc {"organism_id = #{self.organism_id}"}
#	def self.aqua_table_alias
#		"vep_ensembls"
#	end
#
#end