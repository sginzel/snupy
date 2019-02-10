class Vep < ActiveRecord::Base
	
	@@DEFAULT_CONSEQUENCES = %w(frameshift_variant
								incomplete_terminal_codon_variant
								inframe_deletion
								inframe_insertion
								initiator_codon_variant
								mature_miRNA_variant
								missense_variant
								splice_acceptor_variant
								splice_donor_variant
								start_lost
								5_prime_UTR_premature_start_codon_gain_variant
								stop_gained
								stop_lost
								stop_retained_variant
								TF_binding_site_variant
								TFBS_ablation)
	
	@@AMINO_ACIDS = {
			"A" => "Ala",
			"B" => "Asx",
			"C" => "Cys",
			"D" => "Asp",
			"E" => "Glu",
			"F" => "Phe",
			"G" => "Gly",
			"H" => "His",
			"I" => "Ile",
			"K" => "Lys",
			"L" => "Leu",
			"M" => "Met",
			"N" => "Asn",
			"P" => "Pro",
			"Q" => "Gln",
			"R" => "Arg",
			"S" => "Ser",
			"T" => "Thr",
			"V" => "Val",
			"W" => "Trp",
			"X" => "Xaa",
			"Y" => "Tyr",
			"Z" => "Glx",
			"-" => "Indel"}
	@@AA_GROUPS = {
		all: @@AMINO_ACIDS.keys.reject{|x| x == "-"},
		small: %w(A C D G T N S T P),
		tiny: %w(A C G S),
		aromatic: %w(F Y W H),
		hydrophobic: %w(A C G T V I L F Y W H K M),
		polar: %w(S N Q C D E T K R H Y W),
		aliphatic: %w(I V L),
		charged: %w(D E K H R),
		positive: %w(H K R),
		negative: %w(D E),
		proline: %w(P)
	}
	
	@@AA_GROUPS_REVERSE = {}
	@@AA_GROUPS_REVERSE["-"] = ["Indel"]
	@@AA_GROUPS.keys.reject{|x| x == :all}.each do |aagroup|
		@@AA_GROUPS[aagroup].each do |aa|
			next if aagroup.to_s == ""
			next if aa.to_s == ""
			@@AA_GROUPS_REVERSE[aa] = [] if @@AA_GROUPS_REVERSE[aa].nil?
			@@AA_GROUPS_REVERSE[aa] << aagroup
			@@AA_GROUPS_REVERSE[aa].uniq!
			@@AA_GROUPS_REVERSE[aa].sort!
		end
	end
	@@AA_GROUPS_REVERSE.default = "unknown"
	
	@@VEPCONFIG = YAML.load_file(File.join(Rails.root, "extras", "snupy_again", "aqua", "annotations" ,"vep", "vep_config.yaml"))[Rails.env]
	self.table_name = "veps_v#{@@VEPCONFIG["ensembl_version"]}s".to_sym # there is a pending s to be confirm with RAILS pluralized table form
	
	belongs_to :variation
	belongs_to :organism
	has_one :alteration, through: :variation
	has_one :region, through: :variation
	has_many :variation_calls, foreign_key: :variation_id, primary_key: :variation_id
	has_many :samples, through: :variation_calls
	has_many :users, through: :samples
	has_many :experiments, through: :samples
	
	attr_accessible :variation_id,
								:organism_id,
								:impact,
								:consequence,
								:source, #source field, Ensembl or RefSeq
								:biotype,
								:most_severe_consequence,
								:dbsnp,
								:dbsnp_allele,
								:minor_allele,
								:minor_allele_freq,
								:exac_adj_allele,
								:exac_adj_maf,
								:gene_id,
								:transcript_id,
								:gene_symbol,
								:ccds,
								:cdna_start,
								:cdna_end,
								:cds_start,
								:cds_end,
								:canonical,
								:protein_id,
								:protein_start,
								:protein_end,
								:amino_acids,
								:codons,
								# :numbers, #intron or exon
								:numbers1,
								:numbers2,
								:hgvsc,
								:hgvsp,
								:hgvs_offset,
								:distance,
								:trembl_id,
								:uniparc,
								:swissprot,
								:polyphen_prediction,
								:polyphen_score,
								:sift_prediction,
								:sift_score,
								:pubmed,
								:domains,
								:somatic,
								:gene_pheno,
								:phenotype_or_disease,
								:motif_feature_id,
								:motif_name,
								:high_inf_pos,
								:motif_pos,
								:motif_score_change,
								:allele_is_minor,
								:clin_sig,
								:bp_overlap,
								:percentage_overlap
	
	def self.DEFAULT_CONSEQUENCES
		@@DEFAULT_CONSEQUENCES
	end
	
	def self.AMINO_ACIDS
		@@AMINO_ACIDS
	end
	
	def self.AA_GROUPS
		@@AA_GROUPS
	end
	
	def self.AA_GROUPS_REVERSE
		@@AA_GROUPS_REVERSE
	end
	
	def self.colnames
		self.attribute_names.map{|a|
			self.colname(a, "")
		}
	end
	
	def self.colnames_quoted(quote_char = "`")
		self.attribute_names.map{|a|
			self.colname_quoted(a, quote_char)
		}
	end
	
	def self.colname(attr)
		self.colname_quoted(attr, "")
	end
	
	def self.colname_quoted(attr, quote_char = "`")
		# tblname = self.table_name
		# tblname = self.aqua_table_alias if self.respond_to?(:aqua_table_alias)
		tblname = self.aqua_table_alias
		"#{quote_char}#{tblname}.#{attr}#{quote_char}"
	end
	
	def self.aqua_table_alias
		self.table_name
	end
	
	def self.key(attr)
		self.colname(attr)
	end

end

class Vep::Ensembl < Vep
	self.inheritance_column = 'source'
	self.store_full_sti_class = false # if we don't do this ActiveRecord assumes the value to be Vep::Ensembl instead of Ensembl
	
	# TODO the conditions fail when we use Vep::Ensembl.joins(:ref_seqs) 
	#      because then self is a ActiveRecord::Associations::JoinDependency::JoinAssociation object 
	#      and we should use table aliases to specify that vep83_ensembls.organism_id = vep83_refseqs.organism_id
	has_many :ref_seq, :class_name => "Vep::RefSeq",
		:foreign_key => "variation_id", conditions: proc {"organism_id = #{self.organism_id}"}
	# VariationCall.has_many(:"vep_ensembl", {class_name: "Vep::Ensembl", foreign_key: :variation_id, primary_key: :variation_id})
	def self.aqua_table_alias
		# "vep#{@@VEPCONFIG["ensembl_version"]}_ensembls"
		"vep_ensembls"
	end
	
end

class Vep::RefSeq < Vep
	self.inheritance_column = 'source'
	self.store_full_sti_class = false # if we don't do this ActiveRecord assumes the value to be Vep::RefSeq instead of RefSeq
	has_many :ensembl, :class_name => "Vep::Ensembl",
		:foreign_key => "variation_id", conditions: proc {"organism_id = #{self.organism_id}"}
	# VariationCall.has_many(:"vep_refseq", {class_name: "Vep::RefSeq", foreign_key: :variation_id, primary_key: :variation_id})
	def self.aqua_table_alias
		# "vep#{@@VEPCONFIG["ensembl_version"]}_refseqs"
		"vep_refseqs"
	end
	
end

#class Vep::Jaspar < Vep
#	self.inheritance_column = 'source'
#	self.store_full_sti_class = false # if we don't do this ActiveRecord assumes the value to be Vep::RefSeq instead of RefSeq
#	has_many :ensembl, :class_name => "Vep::Ensembl",
#		:foreign_key => "variation_id"
#	has_many :ref_seq, :class_name => "Vep::RefSeq",
#		:foreign_key => "variation_id"
#	
#	def self.aqua_table_alias
#		"vep83_jaspars"
#	end
#	
#end