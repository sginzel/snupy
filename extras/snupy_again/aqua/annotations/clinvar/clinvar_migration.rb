class ClinvarMigration < ActiveRecord::Migration
	@@CLINVARCONFIG          = YAML.load_file(File.join(Aqua.annotationdir ,"clinvar", "clinvar_config.yaml"))[Rails.env]
	@@CLINVARTABLENAME       = "clinvar#{@@CLINVARCONFIG["version"].to_s.gsub(".", "_")}s".to_sym # there is a pending s to be confirm with RAILS pluralized table form
	@@EVIDENCETABLENAME       = "clinvar_evidence#{@@CLINVARCONFIG["version"].to_s.gsub(".", "_")}s".to_sym # there is a pending s to be confirm with RAILS pluralized table form

##INFO=<ID=AF_ESP,Number=1,Type=Float,Description="allele frequencies from GO-ESP">
##INFO=<ID=AF_EXAC,Number=1,Type=Float,Description="allele frequencies from ExAC">
##INFO=<ID=AF_TGP,Number=1,Type=Float,Description="allele frequencies from TGP">
#OK ##INFO=<ID=ALLELEID,Number=1,Type=Integer,Description="the ClinVar Allele ID">
##INFO=<ID=CLNDN,Number=.,Type=String,Description="ClinVar's preferred disease name for the concept specified by disease identifiers in CLNDISDB">
##INFO=<ID=CLNDNINCL,Number=.,Type=String,Description="For included Variant : ClinVar's preferred disease name for the concept specified by disease identifiers in CLNDISDB">
##INFO=<ID=CLNDISDB,Number=.,Type=String,Description="Tag-value pairs of disease database name and identifier, e.g. OMIM:NNNNNN">
##INFO=<ID=CLNDISDBINCL,Number=.,Type=String,Description="For included Variant: Tag-value pairs of disease database name and identifier, e.g. OMIM:NNNNNN">
##INFO=<ID=CLNHGVS,Number=.,Type=String,Description="Top-level (primary assembly, alt, or patch) HGVS expression.">
##INFO=<ID=CLNREVSTAT,Number=.,Type=String,Description="ClinVar review status for the Variation ID">
##INFO=<ID=CLNSIG,Number=.,Type=String,Description="Clinical significance for this single variant">
##INFO=<ID=CLNSIGCONF,Number=.,Type=String,Description="Conflicting clinical significance for this single variant">
##INFO=<ID=CLNSIGINCL,Number=.,Type=String,Description="Clinical significance for a haplotype or genotype that includes this variant. Reported as pairs of VariationID:clinical significance.">
#OK ##INFO=<ID=CLNVC,Number=1,Type=String,Description="Variant type">
#OK ##INFO=<ID=CLNVCSO,Number=1,Type=String,Description="Sequence Ontology id for variant type">
##INFO=<ID=CLNVI,Number=.,Type=String,Description="the variant's clinical sources reported as tag-value pairs of database and variant identifier">
##INFO=<ID=DBVARID,Number=.,Type=String,Description="nsv accessions from dbVar for the variant">
##INFO=<ID=GENEINFO,Number=1,Type=String,Description="Gene(s) for the variant reported as gene symbol:gene id. The gene symbol and id are delimited by a colon (:) and each pair is delimited by a vertical bar (|)">
#NOTUSED ##INFO=<ID=MC,Number=.,Type=String,Description="comma separated list of molecular consequence in the form of Sequence Ontology ID|molecular_consequence">
##INFO=<ID=ORIGIN,Number=.,Type=String,Description="Allele origin. One or more of the following values may be added: 0 - unknown; 1 - germline; 2 - somatic; 4 - inherited; 8 - paternal; 16 - maternal; 32 -de-novo; 64 - biparental; 128 - uniparental; 256 - not-tested; 512 - tested-inconclusive; 1073741824 - other">
#NOTUSED ##INFO=<ID=RS,Number=.,Type=String,Description="dbSNP ID (i.e. rs number)">
#NOTUSED ##INFO=<ID=SSR,Number=1,Type=Integer,Description="Variant Suspect Reason Codes. One or more of the following values may be added: 0 - unspecified, 1 - Paralog, 2 - byEST, 4 - oldAlign, 8 - Para_EST, 16 -1kg_failed, 1024 - other">
	
	# create the table here
	# Clinvar contains the variant/gene disease association
	# ClinvarEvidence contains all the additional information
	def up
		create_table @@CLINVARTABLENAME  do |t|
			t.references :variation, null: false # required
			t.references :organism, null: false # required
			t.references :clinvar_evidence # clinvar record
			t.integer    :alleleid
			t.integer    :distance # distance from closest clinvar entry
			t.string     :symbol # GENEINFO
			t.string     :geneid # GENEINFO
			t.string     :clndn
			t.boolean    :allele_match # is true if the variant and CLINVAR mutation match
			t.boolean    :is_reviewed
			#CLNSIG
			t.boolean    :is_pathogenic
			t.boolean    :is_likely_benign
			t.boolean    :is_benign
			t.boolean    :is_likely_pathogenic
			t.boolean    :is_drug_response
			t.boolean    :is_association
			t.boolean    :is_risk_factor
			t.boolean    :is_protective
			t.boolean    :is_uncertain_significance
			t.boolean    :is_other_significance
			t.boolean    :is_not_provided
			#CLNSIGCONF
			t.boolean    :is_conflicting
			# ORIGIN
			#0 - unknown; 1 - germline; 2 - somatic; 4 - inherited; 8 - paternal; 16 - maternal; 32 -de-novo; 64 - biparental;
			#128 - uniparental; 256 - not-tested; 512 - tested-inconclusive; 1073741824
			t.boolean    :origin_unknown
			t.boolean    :origin_germline
			t.boolean    :origin_somatic
			t.boolean    :origin_inherited
			t.boolean    :origin_parental
			t.boolean    :origin_maternal
			t.boolean    :origin_denovo
			t.boolean    :origin_biparental
			t.boolean    :origin_uniparental
			t.boolean    :origin_nottested
			t.boolean    :origin_inconclusive
		end
		
		create_table @@EVIDENCETABLENAME do |t|
			t.references :variation, null: false # required
			t.references :organism, null: false # required
			t.integer    :alleleid
			t.string     :geneinfo
			t.string     :clndn # CLNDN
			t.string     :clndnincl #CLNDNINCL
			t.string     :clnhgvs
			t.string     :clnrevstat
			t.string     :clnsig # CLNSIG
			t.string     :clnsigconf #CLNSIGCONF
			t.integer     :origin
			t.string     :clnsigincl
			t.integer    :clnsigincl_alleleid
			t.string     :clnsigincl_clnsig
		end
		
		add_index @@CLINVARTABLENAME, :variation_id
		add_index @@CLINVARTABLENAME, :organism_id
		add_index @@CLINVARTABLENAME, :clinvar_evidence_id
		add_index @@CLINVARTABLENAME, :is_reviewed
		add_index @@CLINVARTABLENAME, :alleleid
		add_index @@CLINVARTABLENAME, :distance
		add_index @@CLINVARTABLENAME, :symbol
		add_index @@CLINVARTABLENAME, :geneid
		add_index @@CLINVARTABLENAME, :clndn
		add_index @@CLINVARTABLENAME, :allele_match
		add_index @@CLINVARTABLENAME, :is_pathogenic
		add_index @@CLINVARTABLENAME, :is_likely_benign
		add_index @@CLINVARTABLENAME, :is_benign
		add_index @@CLINVARTABLENAME, :is_likely_pathogenic
		add_index @@CLINVARTABLENAME, :is_drug_response
		add_index @@CLINVARTABLENAME, :is_association
		add_index @@CLINVARTABLENAME, :is_risk_factor
		add_index @@CLINVARTABLENAME, :is_protective
		add_index @@CLINVARTABLENAME, :is_uncertain_significance
		add_index @@CLINVARTABLENAME, :is_other_significance
		add_index @@CLINVARTABLENAME, :is_not_provided
		add_index @@CLINVARTABLENAME, :is_conflicting
		add_index @@CLINVARTABLENAME, :origin_unknown
		add_index @@CLINVARTABLENAME, :origin_germline
		add_index @@CLINVARTABLENAME, :origin_somatic
		add_index @@CLINVARTABLENAME, :origin_inherited
		add_index @@CLINVARTABLENAME, :origin_parental
		add_index @@CLINVARTABLENAME, :origin_maternal
		add_index @@CLINVARTABLENAME, :origin_denovo
		add_index @@CLINVARTABLENAME, :origin_biparental
		add_index @@CLINVARTABLENAME, :origin_uniparental
		add_index @@CLINVARTABLENAME, :origin_nottested
		add_index @@CLINVARTABLENAME, :origin_inconclusive
		add_index @@CLINVARTABLENAME, [:variation_id, :clinvar_evidence_id, :clndn], unique: true, name: "unique_evidence_relation"
		
		add_index @@EVIDENCETABLENAME, :variation_id
		add_index @@EVIDENCETABLENAME, :organism_id
		add_index @@EVIDENCETABLENAME, :alleleid
		add_index @@EVIDENCETABLENAME, :geneinfo
		add_index @@EVIDENCETABLENAME, :clndn
		add_index @@EVIDENCETABLENAME, :clndnincl
		add_index @@EVIDENCETABLENAME, :clnhgvs
		add_index @@EVIDENCETABLENAME, :clnrevstat
		add_index @@EVIDENCETABLENAME, :clnsig
		add_index @@EVIDENCETABLENAME, :clnsigconf
		add_index @@EVIDENCETABLENAME, :origin
		add_index @@EVIDENCETABLENAME, :clnsigincl
		add_index @@EVIDENCETABLENAME, :clnsigincl_alleleid
		add_index @@EVIDENCETABLENAME, :clnsigincl_clnsig
		add_index @@EVIDENCETABLENAME, [:variation_id, :organism_id, :alleleid], unique: true, name: "unique_evidence"
		
		puts "#{@@CLINVARTABLENAME} & #{@@EVIDENCETABLENAME} for clinvar has been migrated.".green
		puts "In case you used scaffolding: Remember to activate your AQuA components setting activate: true".yellow
	end
	
	# destroy tables here
	def down
		drop_table @@CLINVARTABLENAME
		drop_table @@EVIDENCETABLENAME
		puts "#{@@CLINVARTABLENAME} & #{@@EVIDENCETABLENAME} have been dropped.".yellow
		puts "Remember to de-activate your AQuA components setting activate: false".red
	end

end