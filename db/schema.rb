# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20190201103447) do

  create_table "affiliations", :force => true do |t|
    t.integer "user_id"
    t.integer "institution_id"
    t.string  "roles"
  end

  add_index "affiliations", ["institution_id"], :name => "index_affiliations_on_institution_id"
  add_index "affiliations", ["roles"], :name => "index_affiliations_on_roles"
  add_index "affiliations", ["user_id"], :name => "index_affiliations_on_user_id"

  create_table "alterations", :force => true do |t|
    t.string   "ref",        :limit => 2048, :null => false
    t.string   "alt",        :limit => 2048, :null => false
    t.string   "alttype",                    :null => false
    t.datetime "created_at",                 :null => false
    t.datetime "updated_at",                 :null => false
  end

  add_index "alterations", ["alt"], :name => "index_alterations_on_alt", :length => {"alt"=>767}
  add_index "alterations", ["alttype"], :name => "index_alterations_on_alttype"
  add_index "alterations", ["ref", "alt"], :name => "unique_ref_alt_pairs", :unique => true, :length => {"ref"=>382, "alt"=>382}
  add_index "alterations", ["ref"], :name => "index_alterations_on_ref", :length => {"ref"=>767}

  create_table "annovar_ensembl2alias", :force => true do |t|
    t.string  "ensembl_id",  :null => false
    t.string  "alias",       :null => false
    t.string  "dbname",      :null => false
    t.integer "organism_id", :null => false
  end

  add_index "annovar_ensembl2alias", ["alias"], :name => "index_annovar_ensembl2alias_on_alias"
  add_index "annovar_ensembl2alias", ["dbname"], :name => "index_annovar_ensembl2alias_on_dbname"
  add_index "annovar_ensembl2alias", ["ensembl_id"], :name => "index_annovar_ensembl2alias_on_ensembl_id"
  add_index "annovar_ensembl2alias", ["organism_id"], :name => "index_annovar_ensembl2alias_on_organism_id"

  create_table "annovars", :force => true do |t|
    t.integer  "variation_id",                                   :null => false
    t.integer  "organism_id",                                    :null => false
    t.string   "ensembl_annovar_annotation"
    t.string   "ensembl_annotation"
    t.string   "ensembl_gene"
    t.string   "ensembl_effect_transcript"
    t.string   "ensembl_region_sequence_change"
    t.string   "ensembl_dna_sequence_change"
    t.string   "ensembl_protein_sequence_change"
    t.string   "ensembl_right_gene_neighbor"
    t.integer  "ensembl_distance_to_right_gene_neighbor"
    t.string   "ensembl_left_gene_neighbor"
    t.integer  "ensembl_distance_to_left_gene_neighbor"
    t.string   "refgene_annovar_annotation"
    t.string   "refgene_annotation"
    t.string   "refgene_gene"
    t.string   "refgene_effect_transcript"
    t.string   "refgene_region_sequence_change"
    t.string   "refgene_dna_sequence_change"
    t.string   "refgene_protein_sequence_change"
    t.string   "refgene_left_gene_neighbor"
    t.integer  "refgene_distance_to_left_gene_neighbor"
    t.string   "refgene_right_gene_neighbor"
    t.integer  "refgene_distance_to_right_gene_neighbor"
    t.boolean  "ensembl_gene_is_refgene_alias"
    t.boolean  "ensembl_transcript_is_refgene_transcript_alias"
    t.string   "wgrna_name"
    t.string   "micro_rna_target_name"
    t.float    "micro_rna_target_score"
    t.string   "tfbs_motif_name"
    t.float    "tfbs_score"
    t.string   "genomic_super_dups_name"
    t.float    "genomic_super_dups_score"
    t.string   "gwas_catalog"
    t.string   "variant_clinical_significance"
    t.string   "variant_disease_name"
    t.string   "variant_revstat"
    t.string   "variant_accession_versions"
    t.string   "variant_disease_database_name"
    t.string   "variant_disease_database_id"
    t.float    "sift_score"
    t.string   "sift_pred"
    t.float    "polyphen2_hdvi_score"
    t.string   "polyphen2_hdvi_pred"
    t.float    "polyphen2_hvar_score"
    t.string   "polyphen2_hvar_pred"
    t.float    "lrt_score"
    t.string   "lrt_pred"
    t.float    "mutation_taster_score"
    t.string   "mutation_taster_pred"
    t.float    "mutation_assessor_score"
    t.string   "mutation_assessor_pred"
    t.float    "fathmm_score"
    t.string   "fathmm_pred"
    t.float    "radial_svm_score"
    t.string   "radial_svm_pred"
    t.float    "lr_score"
    t.string   "lr_pred"
    t.float    "vest3_score"
    t.float    "cadd_raw"
    t.float    "cadd_phred"
    t.float    "gerp_rs"
    t.float    "phylop46way_placental"
    t.float    "phylop100way_vertebrate"
    t.float    "siphy_29way_logOdds"
    t.float    "genome_2014oct"
    t.string   "snp138"
    t.float    "esp6500siv2_all"
    t.float    "gerp_gt2"
    t.float    "cg69"
    t.string   "cosmic68_id"
    t.string   "cosmic68_occurence"
    t.float    "exac_all"
    t.datetime "created_at",                                     :null => false
    t.datetime "updated_at",                                     :null => false
  end

  add_index "annovars", ["cadd_phred"], :name => "index_annovars_on_cadd_phred"
  add_index "annovars", ["cadd_raw"], :name => "index_annovars_on_cadd_raw"
  add_index "annovars", ["cg69"], :name => "index_annovars_on_cg69"
  add_index "annovars", ["cosmic68_id"], :name => "index_annovars_on_cosmic68_id"
  add_index "annovars", ["cosmic68_occurence"], :name => "index_annovars_on_cosmic68_occurence"
  add_index "annovars", ["ensembl_annotation"], :name => "index_annovars_on_ensembl_annotation"
  add_index "annovars", ["ensembl_annovar_annotation"], :name => "index_annovars_on_ensembl_annovar_annotation"
  add_index "annovars", ["ensembl_effect_transcript"], :name => "index_annovars_on_ensembl_effect_transcript"
  add_index "annovars", ["ensembl_gene"], :name => "index_annovars_on_ensembl_gene"
  add_index "annovars", ["ensembl_gene_is_refgene_alias"], :name => "index_annovars_on_ensembl_gene_is_refgene_alias"
  add_index "annovars", ["ensembl_transcript_is_refgene_transcript_alias"], :name => "index_annovars_on_ensembl_transcript_is_refgene_transcript_alias"
  add_index "annovars", ["esp6500siv2_all"], :name => "index_annovars_on_esp6500siv2_all"
  add_index "annovars", ["exac_all"], :name => "index_annovars_on_exac_all"
  add_index "annovars", ["fathmm_pred"], :name => "index_annovars_on_fathmm_pred"
  add_index "annovars", ["fathmm_score"], :name => "index_annovars_on_fathmm_score"
  add_index "annovars", ["genome_2014oct"], :name => "index_annovars_on_genome_2014oct"
  add_index "annovars", ["gerp_gt2"], :name => "index_annovars_on_gerp_gt2"
  add_index "annovars", ["gerp_rs"], :name => "index_annovars_on_gerp_rs"
  add_index "annovars", ["gwas_catalog"], :name => "index_annovars_on_gwas_catalog"
  add_index "annovars", ["lr_pred"], :name => "index_annovars_on_lr_pred"
  add_index "annovars", ["lr_score"], :name => "index_annovars_on_lr_score"
  add_index "annovars", ["lrt_pred"], :name => "index_annovars_on_lrt_pred"
  add_index "annovars", ["lrt_score"], :name => "index_annovars_on_lrt_score"
  add_index "annovars", ["micro_rna_target_name"], :name => "index_annovars_on_micro_rna_target_name"
  add_index "annovars", ["micro_rna_target_score"], :name => "index_annovars_on_micro_rna_target_score"
  add_index "annovars", ["mutation_assessor_pred"], :name => "index_annovars_on_mutation_assessor_pred"
  add_index "annovars", ["mutation_assessor_score"], :name => "index_annovars_on_mutation_assessor_score"
  add_index "annovars", ["mutation_taster_pred"], :name => "index_annovars_on_mutation_taster_pred"
  add_index "annovars", ["mutation_taster_score"], :name => "index_annovars_on_mutation_taster_score"
  add_index "annovars", ["organism_id"], :name => "index_annovars_on_organism_id"
  add_index "annovars", ["phylop100way_vertebrate"], :name => "index_annovars_on_phylop100way_vertebrate"
  add_index "annovars", ["phylop46way_placental"], :name => "index_annovars_on_phylop46way_placental"
  add_index "annovars", ["polyphen2_hdvi_pred"], :name => "index_annovars_on_polyphen2_hdvi_pred"
  add_index "annovars", ["polyphen2_hdvi_score"], :name => "index_annovars_on_polyphen2_hdvi_score"
  add_index "annovars", ["polyphen2_hvar_pred"], :name => "index_annovars_on_polyphen2_hvar_pred"
  add_index "annovars", ["polyphen2_hvar_score"], :name => "index_annovars_on_polyphen2_hvar_score"
  add_index "annovars", ["radial_svm_pred"], :name => "index_annovars_on_radial_svm_pred"
  add_index "annovars", ["radial_svm_score"], :name => "index_annovars_on_radial_svm_score"
  add_index "annovars", ["refgene_annotation"], :name => "index_annovars_on_refgene_annotation"
  add_index "annovars", ["refgene_annovar_annotation"], :name => "index_annovars_on_refgene_annovar_annotation"
  add_index "annovars", ["refgene_effect_transcript"], :name => "index_annovars_on_refgene_effect_transcript"
  add_index "annovars", ["refgene_gene"], :name => "index_annovars_on_refgene_gene"
  add_index "annovars", ["sift_pred"], :name => "index_annovars_on_sift_pred"
  add_index "annovars", ["sift_score"], :name => "index_annovars_on_sift_score"
  add_index "annovars", ["siphy_29way_logOdds"], :name => "index_annovars_on_siphy_29way_logOdds"
  add_index "annovars", ["snp138"], :name => "index_annovars_on_snp138"
  add_index "annovars", ["tfbs_motif_name"], :name => "index_annovars_on_tfbs_motif_name"
  add_index "annovars", ["tfbs_score"], :name => "index_annovars_on_tfbs_score"
  add_index "annovars", ["variant_clinical_significance"], :name => "index_annovars_on_variant_clinical_significance"
  add_index "annovars", ["variant_disease_name"], :name => "index_annovars_on_variant_disease_name"
  add_index "annovars", ["variation_id"], :name => "index_annovars_on_variation_id"
  add_index "annovars", ["vest3_score"], :name => "index_annovars_on_vest3_score"

  create_table "api_keys", :force => true do |t|
    t.integer  "user_id"
    t.string   "token"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "api_keys", ["token"], :name => "index_api_keys_on_token"
  add_index "api_keys", ["user_id"], :name => "index_api_keys_on_user_id"

  create_table "aqua_quantile_values", :force => true do |t|
    t.integer  "aqua_quantile_id", :null => false
    t.float    "quantile",         :null => false
    t.float    "value"
    t.datetime "created_at",       :null => false
    t.datetime "updated_at",       :null => false
  end

  add_index "aqua_quantile_values", ["aqua_quantile_id", "quantile"], :name => "index_aqua_quantile_values_on_aqua_quantile_id_and_quantile", :unique => true
  add_index "aqua_quantile_values", ["aqua_quantile_id"], :name => "index_aqua_quantile_values_on_aqua_quantile_id"
  add_index "aqua_quantile_values", ["quantile"], :name => "index_aqua_quantile_values_on_quantile"
  add_index "aqua_quantile_values", ["value"], :name => "index_aqua_quantile_values_on_value"

  create_table "aqua_quantiles", :force => true do |t|
    t.string   "model",                                                :null => false
    t.integer  "direction",                             :default => 1
    t.binary   "estimator",         :limit => 16777215
    t.string   "model_table",                                          :null => false
    t.string   "attribute_column",                                     :null => false
    t.integer  "organism_id",                                          :null => false
    t.integer  "last_variation_id",                     :default => 0
    t.datetime "created_at",                                           :null => false
    t.datetime "updated_at",                                           :null => false
  end

  add_index "aqua_quantiles", ["attribute_column"], :name => "index_aqua_quantiles_on_attribute_column"
  add_index "aqua_quantiles", ["direction"], :name => "index_aqua_quantiles_on_direction"
  add_index "aqua_quantiles", ["last_variation_id"], :name => "index_aqua_quantiles_on_last_variation_id"
  add_index "aqua_quantiles", ["model"], :name => "index_aqua_quantiles_on_model"
  add_index "aqua_quantiles", ["model_table", "organism_id", "attribute_column"], :name => "unique_table_attribute_name_organism", :unique => true
  add_index "aqua_quantiles", ["model_table"], :name => "index_aqua_quantiles_on_model_table"
  add_index "aqua_quantiles", ["organism_id"], :name => "index_aqua_quantiles_on_organism_id"

  create_table "aqua_statuses", :force => true do |t|
    t.string   "type"
    t.string   "category"
    t.string   "value"
    t.string   "source"
    t.integer  "xref_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "aqua_statuses", ["category"], :name => "index_aqua_statuses_on_category"
  add_index "aqua_statuses", ["source"], :name => "index_aqua_statuses_on_source"
  add_index "aqua_statuses", ["type"], :name => "index_aqua_statuses_on_type"
  add_index "aqua_statuses", ["value"], :name => "index_aqua_statuses_on_value"
  add_index "aqua_statuses", ["xref_id"], :name => "index_aqua_statuses_on_xref_id"

  create_table "cadd1_3s", :force => true do |t|
    t.integer "variation_id", :null => false
    t.float   "raw"
    t.float   "phred"
    t.integer "organism_id",  :null => false
  end

  add_index "cadd1_3s", ["organism_id"], :name => "index_cadd1_3s_on_organism_id"
  add_index "cadd1_3s", ["phred"], :name => "index_cadd1_3s_on_phred"
  add_index "cadd1_3s", ["raw"], :name => "index_cadd1_3s_on_raw"
  add_index "cadd1_3s", ["variation_id"], :name => "index_cadd1_3s_on_variation_id"

  create_table "capture_kit1_0s", :force => true do |t|
    t.integer "variation_id",                     :null => false
    t.integer "organism_id",                      :null => false
    t.integer "dist",                :limit => 2
    t.integer "capture_kit_file_id",              :null => false
  end

  add_index "capture_kit1_0s", ["capture_kit_file_id"], :name => "index_capture_kit1_0s_on_capture_kit_file_id"
  add_index "capture_kit1_0s", ["dist"], :name => "index_capture_kit1_0s_on_dist"
  add_index "capture_kit1_0s", ["organism_id"], :name => "index_capture_kit1_0s_on_organism_id"
  add_index "capture_kit1_0s", ["variation_id", "capture_kit_file_id"], :name => "index_capture_kit1_0s_on_variation_id_and_capture_kit_file_id", :unique => true
  add_index "capture_kit1_0s", ["variation_id"], :name => "index_capture_kit1_0s_on_variation_id"

  create_table "capture_kit_file1_0s", :force => true do |t|
    t.string  "name",                               :null => false
    t.string  "description"
    t.string  "file",                               :null => false
    t.string  "localfile",                          :null => false
    t.string  "chromosomes",                        :null => false
    t.integer "bp",                                 :null => false
    t.string  "capture_type",                       :null => false
    t.binary  "content",      :limit => 2147483647, :null => false
    t.integer "organism_id",                        :null => false
  end

  add_index "capture_kit_file1_0s", ["bp"], :name => "index_capture_kit_file1_0s_on_bp"
  add_index "capture_kit_file1_0s", ["capture_type"], :name => "index_capture_kit_file1_0s_on_capture_type"
  add_index "capture_kit_file1_0s", ["file"], :name => "index_capture_kit_file1_0s_on_file"
  add_index "capture_kit_file1_0s", ["localfile"], :name => "index_capture_kit_file1_0s_on_localfile"
  add_index "capture_kit_file1_0s", ["name"], :name => "index_capture_kit_file1_0s_on_name"
  add_index "capture_kit_file1_0s", ["organism_id"], :name => "index_capture_kit_file1_0s_on_organism_id"

  create_table "clinvar20180805s", :force => true do |t|
    t.integer "variation_id",              :null => false
    t.integer "organism_id",               :null => false
    t.integer "clinvar_evidence_id"
    t.integer "alleleid"
    t.integer "distance"
    t.string  "symbol"
    t.string  "geneid"
    t.string  "clndn"
    t.boolean "allele_match"
    t.boolean "is_reviewed"
    t.boolean "is_pathogenic"
    t.boolean "is_likely_benign"
    t.boolean "is_benign"
    t.boolean "is_likely_pathogenic"
    t.boolean "is_drug_response"
    t.boolean "is_association"
    t.boolean "is_risk_factor"
    t.boolean "is_protective"
    t.boolean "is_uncertain_significance"
    t.boolean "is_other_significance"
    t.boolean "is_not_provided"
    t.boolean "is_conflicting"
    t.boolean "origin_unknown"
    t.boolean "origin_germline"
    t.boolean "origin_somatic"
    t.boolean "origin_inherited"
    t.boolean "origin_parental"
    t.boolean "origin_maternal"
    t.boolean "origin_denovo"
    t.boolean "origin_biparental"
    t.boolean "origin_uniparental"
    t.boolean "origin_nottested"
    t.boolean "origin_inconclusive"
  end

  add_index "clinvar20180805s", ["allele_match"], :name => "index_clinvar20180805s_on_allele_match"
  add_index "clinvar20180805s", ["alleleid"], :name => "index_clinvar20180805s_on_alleleid"
  add_index "clinvar20180805s", ["clinvar_evidence_id"], :name => "index_clinvar20180805s_on_clinvar_evidence_id"
  add_index "clinvar20180805s", ["clndn"], :name => "index_clinvar20180805s_on_clndn"
  add_index "clinvar20180805s", ["distance"], :name => "index_clinvar20180805s_on_distance"
  add_index "clinvar20180805s", ["geneid"], :name => "index_clinvar20180805s_on_geneid"
  add_index "clinvar20180805s", ["is_association"], :name => "index_clinvar20180805s_on_is_association"
  add_index "clinvar20180805s", ["is_benign"], :name => "index_clinvar20180805s_on_is_benign"
  add_index "clinvar20180805s", ["is_conflicting"], :name => "index_clinvar20180805s_on_is_conflicting"
  add_index "clinvar20180805s", ["is_drug_response"], :name => "index_clinvar20180805s_on_is_drug_response"
  add_index "clinvar20180805s", ["is_likely_benign"], :name => "index_clinvar20180805s_on_is_likely_benign"
  add_index "clinvar20180805s", ["is_likely_pathogenic"], :name => "index_clinvar20180805s_on_is_likely_pathogenic"
  add_index "clinvar20180805s", ["is_not_provided"], :name => "index_clinvar20180805s_on_is_not_provided"
  add_index "clinvar20180805s", ["is_other_significance"], :name => "index_clinvar20180805s_on_is_other_significance"
  add_index "clinvar20180805s", ["is_pathogenic"], :name => "index_clinvar20180805s_on_is_pathogenic"
  add_index "clinvar20180805s", ["is_protective"], :name => "index_clinvar20180805s_on_is_protective"
  add_index "clinvar20180805s", ["is_reviewed"], :name => "index_clinvar20180805s_on_is_reviewed"
  add_index "clinvar20180805s", ["is_risk_factor"], :name => "index_clinvar20180805s_on_is_risk_factor"
  add_index "clinvar20180805s", ["is_uncertain_significance"], :name => "index_clinvar20180805s_on_is_uncertain_significance"
  add_index "clinvar20180805s", ["organism_id"], :name => "index_clinvar20180805s_on_organism_id"
  add_index "clinvar20180805s", ["origin_biparental"], :name => "index_clinvar20180805s_on_origin_biparental"
  add_index "clinvar20180805s", ["origin_denovo"], :name => "index_clinvar20180805s_on_origin_denovo"
  add_index "clinvar20180805s", ["origin_germline"], :name => "index_clinvar20180805s_on_origin_germline"
  add_index "clinvar20180805s", ["origin_inconclusive"], :name => "index_clinvar20180805s_on_origin_inconclusive"
  add_index "clinvar20180805s", ["origin_inherited"], :name => "index_clinvar20180805s_on_origin_inherited"
  add_index "clinvar20180805s", ["origin_maternal"], :name => "index_clinvar20180805s_on_origin_maternal"
  add_index "clinvar20180805s", ["origin_nottested"], :name => "index_clinvar20180805s_on_origin_nottested"
  add_index "clinvar20180805s", ["origin_parental"], :name => "index_clinvar20180805s_on_origin_parental"
  add_index "clinvar20180805s", ["origin_somatic"], :name => "index_clinvar20180805s_on_origin_somatic"
  add_index "clinvar20180805s", ["origin_uniparental"], :name => "index_clinvar20180805s_on_origin_uniparental"
  add_index "clinvar20180805s", ["origin_unknown"], :name => "index_clinvar20180805s_on_origin_unknown"
  add_index "clinvar20180805s", ["symbol"], :name => "index_clinvar20180805s_on_symbol"
  add_index "clinvar20180805s", ["variation_id", "clinvar_evidence_id", "clndn"], :name => "unique_evidence_relation", :unique => true
  add_index "clinvar20180805s", ["variation_id"], :name => "index_clinvar20180805s_on_variation_id"

  create_table "clinvar_evidence20180805s", :force => true do |t|
    t.integer "variation_id",        :null => false
    t.integer "organism_id",         :null => false
    t.integer "alleleid"
    t.string  "geneinfo"
    t.string  "clndn"
    t.string  "clndnincl"
    t.string  "clnhgvs"
    t.string  "clnrevstat"
    t.string  "clnsig"
    t.string  "clnsigconf"
    t.integer "origin"
    t.string  "clnsigincl"
    t.integer "clnsigincl_alleleid"
    t.string  "clnsigincl_clnsig"
  end

  add_index "clinvar_evidence20180805s", ["alleleid"], :name => "index_clinvar_evidence20180805s_on_alleleid"
  add_index "clinvar_evidence20180805s", ["clndn"], :name => "index_clinvar_evidence20180805s_on_clndn"
  add_index "clinvar_evidence20180805s", ["clndnincl"], :name => "index_clinvar_evidence20180805s_on_clndnincl"
  add_index "clinvar_evidence20180805s", ["clnhgvs"], :name => "index_clinvar_evidence20180805s_on_clnhgvs"
  add_index "clinvar_evidence20180805s", ["clnrevstat"], :name => "index_clinvar_evidence20180805s_on_clnrevstat"
  add_index "clinvar_evidence20180805s", ["clnsig"], :name => "index_clinvar_evidence20180805s_on_clnsig"
  add_index "clinvar_evidence20180805s", ["clnsigconf"], :name => "index_clinvar_evidence20180805s_on_clnsigconf"
  add_index "clinvar_evidence20180805s", ["clnsigincl"], :name => "index_clinvar_evidence20180805s_on_clnsigincl"
  add_index "clinvar_evidence20180805s", ["clnsigincl_alleleid"], :name => "index_clinvar_evidence20180805s_on_clnsigincl_alleleid"
  add_index "clinvar_evidence20180805s", ["clnsigincl_clnsig"], :name => "index_clinvar_evidence20180805s_on_clnsigincl_clnsig"
  add_index "clinvar_evidence20180805s", ["geneinfo"], :name => "index_clinvar_evidence20180805s_on_geneinfo"
  add_index "clinvar_evidence20180805s", ["organism_id"], :name => "index_clinvar_evidence20180805s_on_organism_id"
  add_index "clinvar_evidence20180805s", ["origin"], :name => "index_clinvar_evidence20180805s_on_origin"
  add_index "clinvar_evidence20180805s", ["variation_id", "organism_id", "alleleid"], :name => "unique_evidence", :unique => true
  add_index "clinvar_evidence20180805s", ["variation_id"], :name => "index_clinvar_evidence20180805s_on_variation_id"

  create_table "consequences", :force => true do |t|
    t.string   "consequence"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  add_index "consequences", ["consequence"], :name => "index_consequences_on_consequence"

  create_table "delayed_jobs", :force => true do |t|
    t.integer  "priority",   :default => 0
    t.integer  "attempts",   :default => 0
    t.text     "handler"
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.string   "queue"
    t.datetime "created_at",                :null => false
    t.datetime "updated_at",                :null => false
  end

  add_index "delayed_jobs", ["priority", "run_at"], :name => "delayed_jobs_priority"

  create_table "digenics", :force => true do |t|
    t.string   "gene_id",                                  :null => false
    t.string   "gene_partner_id",                          :null => false
    t.float    "score",                   :default => 1.0, :null => false
    t.string   "disease_name"
    t.string   "association_description"
    t.string   "evidence_record"
    t.string   "source_db",                                :null => false
    t.string   "source_id"
    t.string   "source_file",                              :null => false
    t.integer  "organism_id",                              :null => false
    t.datetime "created_at",                               :null => false
    t.datetime "updated_at",                               :null => false
  end

  add_index "digenics", ["association_description"], :name => "index_digenics_on_association_description"
  add_index "digenics", ["disease_name"], :name => "index_digenics_on_disease_name"
  add_index "digenics", ["evidence_record"], :name => "index_digenics_on_evidence_record"
  add_index "digenics", ["gene_id"], :name => "index_digenics_on_gene_id"
  add_index "digenics", ["gene_partner_id"], :name => "index_digenics_on_gene_partner_id"
  add_index "digenics", ["organism_id"], :name => "index_digenics_on_organism_id"
  add_index "digenics", ["score"], :name => "index_digenics_on_score"
  add_index "digenics", ["source_db"], :name => "index_digenics_on_source_db"
  add_index "digenics", ["source_file"], :name => "index_digenics_on_source_file"
  add_index "digenics", ["source_id"], :name => "index_digenics_on_source_id"

  create_table "entities", :force => true do |t|
    t.string   "name"
    t.string   "nickname"
    t.string   "internal_identifier"
    t.string   "contact"
    t.datetime "date_first_diagnosis"
    t.boolean  "family_members_available"
    t.text     "notes"
    t.integer  "entity_group_id"
    t.datetime "created_at",               :null => false
    t.datetime "updated_at",               :null => false
  end

  add_index "entities", ["date_first_diagnosis"], :name => "index_entities_on_date_first_diagnosis"
  add_index "entities", ["entity_group_id"], :name => "index_entities_on_entity_group_id"
  add_index "entities", ["family_members_available"], :name => "index_entities_on_family_members_available"
  add_index "entities", ["internal_identifier"], :name => "index_entities_on_internal_identifier"
  add_index "entities", ["name"], :name => "index_entities_on_name"
  add_index "entities", ["nickname"], :name => "index_entities_on_nickname"

  create_table "entity_groups", :force => true do |t|
    t.string   "name"
    t.boolean  "complete"
    t.string   "contact"
    t.integer  "institution_id"
    t.integer  "organism_id"
    t.datetime "created_at",     :null => false
    t.datetime "updated_at",     :null => false
  end

  add_index "entity_groups", ["complete"], :name => "index_entity_groups_on_complete"
  add_index "entity_groups", ["institution_id"], :name => "index_entity_groups_on_institution_id"
  add_index "entity_groups", ["name"], :name => "index_entity_groups_on_name"
  add_index "entity_groups", ["organism_id"], :name => "index_entity_groups_on_organism_id"

  create_table "event_logs", :force => true do |t|
    t.string   "name"
    t.string   "category"
    t.text     "data",        :limit => 16777215
    t.text     "error",       :limit => 16777215
    t.datetime "started_at"
    t.datetime "finished_at"
    t.float    "duration"
    t.datetime "created_at",                      :null => false
    t.datetime "updated_at",                      :null => false
    t.string   "identifier"
  end

  add_index "event_logs", ["category"], :name => "index_event_logs_on_category"
  add_index "event_logs", ["data"], :name => "index_event_logs_on_data", :length => {"data"=>128}
  add_index "event_logs", ["duration"], :name => "index_event_logs_on_duration"
  add_index "event_logs", ["error"], :name => "index_event_logs_on_error", :length => {"error"=>128}
  add_index "event_logs", ["finished_at"], :name => "index_event_logs_on_finished_at"
  add_index "event_logs", ["identifier"], :name => "index_event_logs_on_identifier"
  add_index "event_logs", ["name"], :name => "index_event_logs_on_name"
  add_index "event_logs", ["started_at"], :name => "index_event_logs_on_started_at"

  create_table "experiment_has_entity_groups", :force => true do |t|
    t.integer "experiment_id"
    t.integer "entity_group_id"
  end

  add_index "experiment_has_entity_groups", ["entity_group_id"], :name => "index_experiment_has_entity_groups_on_entity_group_id"
  add_index "experiment_has_entity_groups", ["experiment_id", "entity_group_id"], :name => "exp_eg_index", :unique => true
  add_index "experiment_has_entity_groups", ["experiment_id"], :name => "index_experiment_has_entity_groups_on_experiment_id"

  create_table "experiment_has_long_jobs", :force => true do |t|
    t.integer "experiment_id"
    t.integer "long_job_id"
  end

  add_index "experiment_has_long_jobs", ["experiment_id"], :name => "index_experiment_has_long_jobs_on_experiment_id"
  add_index "experiment_has_long_jobs", ["long_job_id"], :name => "index_experiment_has_long_jobs_on_long_job_id"

  create_table "experiment_has_user", :force => true do |t|
    t.integer "user_id"
    t.integer "experiment_id"
  end

  add_index "experiment_has_user", ["experiment_id"], :name => "index_experiment_has_user_on_experiment_id"
  add_index "experiment_has_user", ["user_id"], :name => "index_experiment_has_user_on_user_id"

  create_table "experiments", :force => true do |t|
    t.string   "name"
    t.string   "title"
    t.string   "contact"
    t.string   "description"
    t.integer  "institution_id"
    t.datetime "created_at",     :null => false
    t.datetime "updated_at",     :null => false
  end

  add_index "experiments", ["institution_id"], :name => "index_experiments_on_institution_id"
  add_index "experiments", ["name"], :name => "index_experiments_on_name"
  add_index "experiments", ["title"], :name => "index_experiments_on_title"

  create_table "generic_list_has_users", :force => true do |t|
    t.integer "generic_list_id"
    t.integer "user_id"
  end

  add_index "generic_list_has_users", ["generic_list_id"], :name => "index_generic_list_has_users_on_generic_list_id"
  add_index "generic_list_has_users", ["user_id"], :name => "index_generic_list_has_users_on_user_id"

  create_table "generic_list_items", :force => true do |t|
    t.text     "value"
    t.string   "type",            :default => "GenericListItem"
    t.integer  "generic_list_id",                                :null => false
    t.datetime "created_at",                                     :null => false
    t.datetime "updated_at",                                     :null => false
  end

  add_index "generic_list_items", ["generic_list_id"], :name => "index_generic_list_items_on_generic_list_id"
  add_index "generic_list_items", ["type"], :name => "index_generic_list_items_on_type"
  add_index "generic_list_items", ["value"], :name => "index_generic_list_items_on_value", :length => {"value"=>767}

  create_table "generic_lists", :force => true do |t|
    t.string   "name"
    t.string   "title"
    t.text     "description"
    t.string   "type"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  create_table "genetic_elements", :force => true do |t|
    t.string   "ensembl_gene_id"
    t.string   "ensembl_feature_id"
    t.string   "ensembl_feature_type"
    t.string   "hgnc"
    t.string   "ensp"
    t.datetime "created_at",           :null => false
    t.datetime "updated_at",           :null => false
    t.integer  "organism_id"
  end

  add_index "genetic_elements", ["ensembl_feature_id"], :name => "index_genetic_elements_on_ensembl_feature_id"
  add_index "genetic_elements", ["ensembl_feature_type"], :name => "index_genetic_elements_on_ensembl_feature_type"
  add_index "genetic_elements", ["ensembl_gene_id"], :name => "index_genetic_elements_on_ensembl_gene_id"
  add_index "genetic_elements", ["ensp"], :name => "index_genetic_elements_on_ensp"
  add_index "genetic_elements", ["hgnc"], :name => "index_genetic_elements_on_hgnc"
  add_index "genetic_elements", ["organism_id"], :name => "index_genetic_elements_on_organism_id"

  create_table "institution_has_users", :force => true do |t|
    t.integer "user_id"
    t.integer "institution_id"
  end

  add_index "institution_has_users", ["institution_id"], :name => "index_institution_has_users_on_institution_id"
  add_index "institution_has_users", ["user_id"], :name => "index_institution_has_users_on_user_id"

  create_table "institutions", :force => true do |t|
    t.string   "name"
    t.string   "contact"
    t.string   "email"
    t.string   "phone"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "long_jobs", :force => true do |t|
    t.integer  "delayed_job_id"
    t.string   "title"
    t.string   "user"
    t.text     "handle"
    t.string   "method"
    t.text     "parameter",      :limit => 16777215
    t.binary   "result",         :limit => 2147483647
    t.string   "result_view"
    t.string   "status"
    t.string   "status_view"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.boolean  "success"
    t.string   "checksum"
    t.text     "error"
    t.datetime "created_at",                                                :null => false
    t.datetime "updated_at",                                                :null => false
    t.string   "queue",                                :default => "snupy"
  end

  create_table "loss_of_functions", :force => true do |t|
    t.string   "sift"
    t.string   "polyphen"
    t.string   "condel"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "loss_of_functions", ["condel"], :name => "index_loss_of_functions_on_condel"
  add_index "loss_of_functions", ["polyphen"], :name => "index_loss_of_functions_on_polyphen"
  add_index "loss_of_functions", ["sift"], :name => "index_loss_of_functions_on_sift"

  create_table "omim_genemap1809s", :force => true do |t|
    t.string  "phenotype"
    t.string  "phenotype_raw"
    t.string  "gene_name"
    t.string  "symbol"
    t.string  "entrezid"
    t.string  "ensembl_gene_id"
    t.string  "symbol_alias"
    t.string  "mgi_id"
    t.string  "mgi_symbol"
    t.string  "comments"
    t.integer "gene_mim"
    t.integer "phenotype_mim"
    t.boolean "is_nondisease"
    t.boolean "is_susceptible"
    t.boolean "is_provisional"
    t.boolean "map_wildtype"
    t.boolean "map_phenotype"
    t.boolean "map_molecular_known"
    t.boolean "map_chr_deldup"
    t.boolean "link_autosomal"
    t.boolean "link_x"
    t.boolean "link_y"
    t.boolean "link_mitochondrial"
    t.boolean "is_autosomal_recessive"
    t.boolean "is_autosomal_dominant"
    t.boolean "is_multifactorial"
    t.boolean "is_isolated_cases"
    t.boolean "is_digenic_recessive"
    t.boolean "is_mitochondrial"
    t.boolean "is_somatic_mutation"
    t.boolean "is_somatic_mosaicism"
    t.boolean "is_xlinked"
    t.boolean "is_ylinked"
    t.boolean "is_dominant"
    t.boolean "is_recessive"
  end

  add_index "omim_genemap1809s", ["comments"], :name => "index_omim_genemap1809s_on_comments"
  add_index "omim_genemap1809s", ["ensembl_gene_id"], :name => "index_omim_genemap1809s_on_ensembl_gene_id"
  add_index "omim_genemap1809s", ["entrezid"], :name => "index_omim_genemap1809s_on_entrezid"
  add_index "omim_genemap1809s", ["gene_mim"], :name => "index_omim_genemap1809s_on_gene_mim"
  add_index "omim_genemap1809s", ["gene_name"], :name => "index_omim_genemap1809s_on_gene_name"
  add_index "omim_genemap1809s", ["is_autosomal_dominant"], :name => "index_omim_genemap1809s_on_is_autosomal_dominant"
  add_index "omim_genemap1809s", ["is_autosomal_recessive"], :name => "index_omim_genemap1809s_on_is_autosomal_recessive"
  add_index "omim_genemap1809s", ["is_digenic_recessive"], :name => "index_omim_genemap1809s_on_is_digenic_recessive"
  add_index "omim_genemap1809s", ["is_dominant"], :name => "index_omim_genemap1809s_on_is_dominant"
  add_index "omim_genemap1809s", ["is_isolated_cases"], :name => "index_omim_genemap1809s_on_is_isolated_cases"
  add_index "omim_genemap1809s", ["is_mitochondrial"], :name => "index_omim_genemap1809s_on_is_mitochondrial"
  add_index "omim_genemap1809s", ["is_multifactorial"], :name => "index_omim_genemap1809s_on_is_multifactorial"
  add_index "omim_genemap1809s", ["is_nondisease"], :name => "index_omim_genemap1809s_on_is_nondisease"
  add_index "omim_genemap1809s", ["is_provisional"], :name => "index_omim_genemap1809s_on_is_provisional"
  add_index "omim_genemap1809s", ["is_recessive"], :name => "index_omim_genemap1809s_on_is_recessive"
  add_index "omim_genemap1809s", ["is_somatic_mosaicism"], :name => "index_omim_genemap1809s_on_is_somatic_mosaicism"
  add_index "omim_genemap1809s", ["is_somatic_mutation"], :name => "index_omim_genemap1809s_on_is_somatic_mutation"
  add_index "omim_genemap1809s", ["is_susceptible"], :name => "index_omim_genemap1809s_on_is_susceptible"
  add_index "omim_genemap1809s", ["is_xlinked"], :name => "index_omim_genemap1809s_on_is_xlinked"
  add_index "omim_genemap1809s", ["is_ylinked"], :name => "index_omim_genemap1809s_on_is_ylinked"
  add_index "omim_genemap1809s", ["link_autosomal"], :name => "index_omim_genemap1809s_on_link_autosomal"
  add_index "omim_genemap1809s", ["link_mitochondrial"], :name => "index_omim_genemap1809s_on_link_mitochondrial"
  add_index "omim_genemap1809s", ["link_x"], :name => "index_omim_genemap1809s_on_link_x"
  add_index "omim_genemap1809s", ["link_y"], :name => "index_omim_genemap1809s_on_link_y"
  add_index "omim_genemap1809s", ["map_chr_deldup"], :name => "index_omim_genemap1809s_on_map_chr_deldup"
  add_index "omim_genemap1809s", ["map_molecular_known"], :name => "index_omim_genemap1809s_on_map_molecular_known"
  add_index "omim_genemap1809s", ["map_phenotype"], :name => "index_omim_genemap1809s_on_map_phenotype"
  add_index "omim_genemap1809s", ["map_wildtype"], :name => "index_omim_genemap1809s_on_map_wildtype"
  add_index "omim_genemap1809s", ["mgi_id"], :name => "index_omim_genemap1809s_on_mgi_id"
  add_index "omim_genemap1809s", ["mgi_symbol"], :name => "index_omim_genemap1809s_on_mgi_symbol"
  add_index "omim_genemap1809s", ["phenotype"], :name => "index_omim_genemap1809s_on_phenotype"
  add_index "omim_genemap1809s", ["phenotype_mim"], :name => "index_omim_genemap1809s_on_phenotype_mim"
  add_index "omim_genemap1809s", ["phenotype_raw"], :name => "index_omim_genemap1809s_on_phenotype_raw"
  add_index "omim_genemap1809s", ["symbol"], :name => "index_omim_genemap1809s_on_symbol"
  add_index "omim_genemap1809s", ["symbol_alias"], :name => "index_omim_genemap1809s_on_symbol_alias"

  create_table "organisms", :force => true do |t|
    t.string   "name"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "regions", :force => true do |t|
    t.string   "name",         :null => false
    t.integer  "start",        :null => false
    t.integer  "stop",         :null => false
    t.string   "coord_system", :null => false
    t.datetime "created_at",   :null => false
    t.datetime "updated_at",   :null => false
  end

  add_index "regions", ["coord_system"], :name => "index_regions_on_coord_system"
  add_index "regions", ["name", "start", "stop", "coord_system"], :name => "unique_field_combo_region", :unique => true
  add_index "regions", ["name", "start", "stop", "coord_system"], :name => "unique_pairs", :unique => true
  add_index "regions", ["name"], :name => "index_regions_on_name"
  add_index "regions", ["start"], :name => "index_regions_on_start"
  add_index "regions", ["stop"], :name => "index_regions_on_stop"

  create_table "report_has_variations", :id => false, :force => true do |t|
    t.integer "report_id"
    t.integer "variation_id"
  end

  add_index "report_has_variations", ["report_id", "variation_id"], :name => "index_report_has_variations_on_report_id_and_variation_id"
  add_index "report_has_variations", ["report_id"], :name => "index_report_has_variations_on_report_id"

  create_table "reports", :force => true do |t|
    t.string   "name",                                                         :null => false
    t.string   "identifier",                                                   :null => false
    t.integer  "xref_id",                                                      :null => false
    t.string   "xref_klass",                                                   :null => false
    t.string   "type"
    t.binary   "content",        :limit => 16777215,                           :null => false
    t.datetime "valid_until"
    t.integer  "user_id",                                                      :null => false
    t.integer  "institution_id",                                               :null => false
    t.string   "mime_type",                          :default => "text/plain"
    t.string   "description"
    t.datetime "created_at",                                                   :null => false
    t.datetime "updated_at",                                                   :null => false
  end

  add_index "reports", ["description"], :name => "index_reports_on_description"
  add_index "reports", ["identifier"], :name => "index_reports_on_identifier"
  add_index "reports", ["institution_id"], :name => "index_reports_on_institution_id"
  add_index "reports", ["mime_type"], :name => "index_reports_on_mime_type"
  add_index "reports", ["name"], :name => "index_reports_on_name"
  add_index "reports", ["user_id"], :name => "index_reports_on_user_id"
  add_index "reports", ["xref_id"], :name => "index_reports_on_xref_id"
  add_index "reports", ["xref_klass"], :name => "index_reports_on_xref_klass"

  create_table "sample_has_experiments", :force => true do |t|
    t.integer "sample_id"
    t.integer "experiment_id"
  end

  add_index "sample_has_experiments", ["experiment_id"], :name => "index_sample_has_experiments_on_experiment_id"
  add_index "sample_has_experiments", ["sample_id"], :name => "index_sample_has_experiments_on_sample_id"

  create_table "sample_has_sample_tag", :force => true do |t|
    t.integer "sample_id"
    t.integer "sample_tag_id"
  end

  create_table "sample_has_users", :force => true do |t|
    t.integer "sample_id"
    t.integer "user_id"
  end

  add_index "sample_has_users", ["sample_id"], :name => "index_sample_has_users_on_sample_id"
  add_index "sample_has_users", ["user_id"], :name => "index_sample_has_users_on_user_id"

  create_table "sample_tags", :force => true do |t|
    t.string   "tag_name",    :null => false
    t.text     "tag_value",   :null => false
    t.string   "tag_type",    :null => false
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
    t.text     "description"
  end

  add_index "sample_tags", ["tag_name", "tag_type", "tag_value"], :name => "index_sample_tags_on_tag_name_and_tag_type_and_tag_value", :unique => true, :length => {"tag_name"=>128, "tag_type"=>128, "tag_value"=>128}
  add_index "sample_tags", ["tag_name"], :name => "index_sample_tags_on_tag_name"

  create_table "samples", :force => true do |t|
    t.string   "name",                                                      :null => false
    t.string   "patient"
    t.text     "notes"
    t.string   "contact"
    t.string   "gender",                             :default => "unknown"
    t.boolean  "ignorefilter",                       :default => false
    t.integer  "vcf_file_id"
    t.string   "vcf_sample_name"
    t.string   "sample_type"
    t.datetime "created_at",                                                :null => false
    t.datetime "updated_at",                                                :null => false
    t.integer  "min_read_depth",                     :default => 0
    t.text     "info_matches"
    t.string   "status",                             :default => "CREATED"
    t.string   "nickname",                                                  :null => false
    t.string   "filters",           :limit => 16384, :default => "PASS"
    t.integer  "specimen_probe_id"
    t.integer  "entity_id"
    t.integer  "entity_group_id"
  end

  add_index "samples", ["entity_group_id"], :name => "index_samples_on_entity_group_id"
  add_index "samples", ["entity_id"], :name => "index_samples_on_entity_id"
  add_index "samples", ["name"], :name => "index_samples_on_name"
  add_index "samples", ["nickname"], :name => "index_samples_on_nickname"
  add_index "samples", ["patient"], :name => "index_samples_on_patient"
  add_index "samples", ["specimen_probe_id"], :name => "index_samples_on_specimen_probe_id"
  add_index "samples", ["vcf_file_id"], :name => "index_samples_on_vcf_file_id"

  create_table "snp_effs", :force => true do |t|
    t.integer  "variation_id",                        :null => false
    t.integer  "organism_id",                         :null => false
    t.string   "annotation"
    t.string   "annotation_impact"
    t.string   "symbol"
    t.string   "ensembl_gene_id"
    t.string   "ensembl_feature_type"
    t.string   "ensembl_feature_id"
    t.string   "transcript_biotype"
    t.string   "hgvs_c"
    t.string   "hgvs_p"
    t.integer  "cdna_pos"
    t.integer  "cdna_length"
    t.integer  "cds_pos"
    t.integer  "cds_length"
    t.integer  "aa_pos"
    t.integer  "aa_length"
    t.integer  "distance"
    t.integer  "genotype_number"
    t.string   "lof_gene_name"
    t.integer  "lof_gene_id"
    t.integer  "lof_number_of_transcripts_in_gene"
    t.float    "lof_percent_of_transcripts_affected"
    t.string   "nmd_gene_name"
    t.integer  "nmd_gene_id"
    t.integer  "nmd_number_of_transcripts_in_gene"
    t.float    "nmd_percent_of_transcripts_affected"
    t.datetime "created_at",                          :null => false
    t.datetime "updated_at",                          :null => false
  end

  add_index "snp_effs", ["annotation"], :name => "index_snp_effs_on_annotation"
  add_index "snp_effs", ["annotation_impact"], :name => "index_snp_effs_on_annotation_impact"
  add_index "snp_effs", ["ensembl_feature_id"], :name => "index_snp_effs_on_ensembl_feature_id"
  add_index "snp_effs", ["ensembl_feature_type"], :name => "index_snp_effs_on_ensembl_feature_type"
  add_index "snp_effs", ["ensembl_gene_id"], :name => "index_snp_effs_on_ensembl_gene_id"
  add_index "snp_effs", ["lof_number_of_transcripts_in_gene"], :name => "index_snp_effs_on_lof_number_of_transcripts_in_gene"
  add_index "snp_effs", ["lof_percent_of_transcripts_affected"], :name => "index_snp_effs_on_lof_percent_of_transcripts_affected"
  add_index "snp_effs", ["nmd_gene_name"], :name => "index_snp_effs_on_nmd_gene_name"
  add_index "snp_effs", ["organism_id"], :name => "index_snp_effs_on_organism_id"
  add_index "snp_effs", ["symbol"], :name => "index_snp_effs_on_symbol"
  add_index "snp_effs", ["transcript_biotype"], :name => "index_snp_effs_on_transcript_biotype"
  add_index "snp_effs", ["variation_id"], :name => "index_snp_effs_on_variation_id"

  create_table "some_table_shutdown", :force => true do |t|
    t.integer  "variation_id", :null => false
    t.integer  "organism_id",  :null => false
    t.string   "some_value"
    t.datetime "created_at",   :null => false
    t.datetime "updated_at",   :null => false
  end

  create_table "sometest_bl", :force => true do |t|
    t.string "somcol", :limit => 45
  end

  create_table "specimen_probes", :force => true do |t|
    t.integer  "entity_id"
    t.string   "name"
    t.text     "notes"
    t.integer  "date_day"
    t.integer  "date_month"
    t.integer  "date_year"
    t.string   "lab"
    t.string   "lab_contact"
    t.string   "internal_identifier"
    t.float    "tumor_content"
    t.string   "tumor_content_notes"
    t.integer  "days_after_treatment"
    t.boolean  "queryable",            :default => false
    t.datetime "created_at",                              :null => false
    t.datetime "updated_at",                              :null => false
  end

  add_index "specimen_probes", ["date_day"], :name => "index_specimen_probes_on_date_day"
  add_index "specimen_probes", ["date_month"], :name => "index_specimen_probes_on_date_month"
  add_index "specimen_probes", ["date_year"], :name => "index_specimen_probes_on_date_year"
  add_index "specimen_probes", ["days_after_treatment"], :name => "index_specimen_probes_on_days_after_treatment"
  add_index "specimen_probes", ["entity_id", "name"], :name => "index_specimen_probes_on_entity_id_and_name", :unique => true
  add_index "specimen_probes", ["entity_id"], :name => "index_specimen_probes_on_entity_id"
  add_index "specimen_probes", ["internal_identifier"], :name => "index_specimen_probes_on_internal_identifier"
  add_index "specimen_probes", ["lab"], :name => "index_specimen_probes_on_lab"
  add_index "specimen_probes", ["lab_contact"], :name => "index_specimen_probes_on_lab_contact"
  add_index "specimen_probes", ["name"], :name => "index_specimen_probes_on_name"
  add_index "specimen_probes", ["queryable"], :name => "index_specimen_probes_on_queryable"
  add_index "specimen_probes", ["tumor_content"], :name => "index_specimen_probes_on_tumor_content"
  add_index "specimen_probes", ["tumor_content_notes"], :name => "index_specimen_probes_on_tumor_content_notes"

  create_table "statistics", :force => true do |t|
    t.integer  "record_id",                                             :null => false
    t.string   "type",                                                  :null => false
    t.string   "name"
    t.binary   "value",      :limit => 2147483647
    t.string   "resource",                                              :null => false
    t.string   "plotstyle",                        :default => "table"
    t.datetime "created_at",                                            :null => false
    t.datetime "updated_at",                                            :null => false
  end

  add_index "statistics", ["record_id", "resource"], :name => "index_statistics_on_record_id_and_resource"
  add_index "statistics", ["record_id"], :name => "index_statistics_on_record_id"
  add_index "statistics", ["resource"], :name => "index_statistics_on_resource"
  add_index "statistics", ["type"], :name => "index_statistics_on_type"

  create_table "string_protein_actions", :force => true do |t|
    t.string  "stringdb1_id",               :null => false
    t.string  "stringdb2_id",               :null => false
    t.string  "mode"
    t.string  "action"
    t.string  "a_is_acting"
    t.string  "score"
    t.integer "bind",          :limit => 2
    t.integer "biocarta",      :limit => 2
    t.integer "biocyc",        :limit => 2
    t.integer "dip",           :limit => 2
    t.integer "grid",          :limit => 2
    t.integer "hprd",          :limit => 2
    t.integer "intact",        :limit => 2
    t.integer "kegg_pathways", :limit => 2
    t.integer "mint",          :limit => 2
    t.integer "pdb",           :limit => 2
    t.integer "pid",           :limit => 2
    t.integer "reactome",      :limit => 2
    t.integer "taxon_id"
    t.integer "organism_id",                :null => false
  end

  add_index "string_protein_actions", ["a_is_acting"], :name => "index_string_protein_actions_on_a_is_acting"
  add_index "string_protein_actions", ["action"], :name => "index_string_protein_actions_on_action"
  add_index "string_protein_actions", ["bind"], :name => "index_string_protein_actions_on_bind"
  add_index "string_protein_actions", ["biocarta"], :name => "index_string_protein_actions_on_biocarta"
  add_index "string_protein_actions", ["biocyc"], :name => "index_string_protein_actions_on_biocyc"
  add_index "string_protein_actions", ["dip"], :name => "index_string_protein_actions_on_dip"
  add_index "string_protein_actions", ["grid"], :name => "index_string_protein_actions_on_grid"
  add_index "string_protein_actions", ["hprd"], :name => "index_string_protein_actions_on_hprd"
  add_index "string_protein_actions", ["intact"], :name => "index_string_protein_actions_on_intact"
  add_index "string_protein_actions", ["kegg_pathways"], :name => "index_string_protein_actions_on_kegg_pathways"
  add_index "string_protein_actions", ["mint"], :name => "index_string_protein_actions_on_mint"
  add_index "string_protein_actions", ["mode"], :name => "index_string_protein_actions_on_mode"
  add_index "string_protein_actions", ["organism_id"], :name => "index_string_protein_actions_on_organism_id"
  add_index "string_protein_actions", ["pdb"], :name => "index_string_protein_actions_on_pdb"
  add_index "string_protein_actions", ["pid"], :name => "index_string_protein_actions_on_pid"
  add_index "string_protein_actions", ["reactome"], :name => "index_string_protein_actions_on_reactome"
  add_index "string_protein_actions", ["score"], :name => "index_string_protein_actions_on_score"
  add_index "string_protein_actions", ["stringdb1_id"], :name => "index_string_protein_actions_on_stringdb1_id"
  add_index "string_protein_actions", ["stringdb2_id"], :name => "index_string_protein_actions_on_stringdb2_id"
  add_index "string_protein_actions", ["taxon_id"], :name => "index_string_protein_actions_on_taxon_id"

  create_table "string_protein_alias", :force => true do |t|
    t.string  "stringdb_id",        :null => false
    t.string  "ensembl_protein_id", :null => false
    t.string  "alias",              :null => false
    t.string  "source"
    t.integer "taxon_id"
    t.integer "organism_id",        :null => false
  end

  add_index "string_protein_alias", ["alias"], :name => "index_string_protein_alias_on_alias"
  add_index "string_protein_alias", ["ensembl_protein_id"], :name => "index_string_protein_alias_on_ensembl_protein_id"
  add_index "string_protein_alias", ["organism_id"], :name => "index_string_protein_alias_on_organism_id"
  add_index "string_protein_alias", ["source"], :name => "index_string_protein_alias_on_source"
  add_index "string_protein_alias", ["stringdb_id"], :name => "index_string_protein_alias_on_stringdb_id"
  add_index "string_protein_alias", ["taxon_id"], :name => "index_string_protein_alias_on_taxon_id"

  create_table "string_protein_links", :force => true do |t|
    t.string   "stringdb1_id",             :null => false
    t.string   "stringdb2_id",             :null => false
    t.integer  "neighborhood"
    t.integer  "neighborhood_transferred"
    t.integer  "fusion"
    t.integer  "cooccurence"
    t.integer  "homology"
    t.integer  "coexpression"
    t.integer  "coexpression_transferred"
    t.integer  "experiments"
    t.integer  "experiments_transferred"
    t.integer  "database"
    t.integer  "database_transferred"
    t.integer  "textmining"
    t.integer  "textmining_transferred"
    t.integer  "combined_score"
    t.integer  "taxon_id"
    t.integer  "organism_id",              :null => false
    t.datetime "created_at",               :null => false
    t.datetime "updated_at",               :null => false
  end

  add_index "string_protein_links", ["coexpression"], :name => "index_string_protein_links_on_coexpression"
  add_index "string_protein_links", ["coexpression_transferred"], :name => "index_string_protein_links_on_coexpression_transferred"
  add_index "string_protein_links", ["combined_score"], :name => "index_string_protein_links_on_combined_score"
  add_index "string_protein_links", ["cooccurence"], :name => "index_string_protein_links_on_cooccurence"
  add_index "string_protein_links", ["database"], :name => "index_string_protein_links_on_database"
  add_index "string_protein_links", ["database_transferred"], :name => "index_string_protein_links_on_database_transferred"
  add_index "string_protein_links", ["experiments"], :name => "index_string_protein_links_on_experiments"
  add_index "string_protein_links", ["experiments_transferred"], :name => "index_string_protein_links_on_experiments_transferred"
  add_index "string_protein_links", ["fusion"], :name => "index_string_protein_links_on_fusion"
  add_index "string_protein_links", ["homology"], :name => "index_string_protein_links_on_homology"
  add_index "string_protein_links", ["neighborhood"], :name => "index_string_protein_links_on_neighborhood"
  add_index "string_protein_links", ["neighborhood_transferred"], :name => "index_string_protein_links_on_neighborhood_transferred"
  add_index "string_protein_links", ["stringdb1_id"], :name => "index_string_protein_links_on_stringdb1_id"
  add_index "string_protein_links", ["stringdb2_id"], :name => "index_string_protein_links_on_stringdb2_id"
  add_index "string_protein_links", ["textmining"], :name => "index_string_protein_links_on_textmining"
  add_index "string_protein_links", ["textmining_transferred"], :name => "index_string_protein_links_on_textmining_transferred"

  create_table "string_proteins", :force => true do |t|
    t.string  "stringdb_id",        :null => false
    t.string  "ensembl_protein_id", :null => false
    t.integer "taxon_id"
    t.integer "organism_id",        :null => false
  end

  add_index "string_proteins", ["ensembl_protein_id"], :name => "index_string_proteins_on_ensembl_protein_id", :unique => true
  add_index "string_proteins", ["organism_id"], :name => "index_string_proteins_on_organism_id"
  add_index "string_proteins", ["stringdb_id"], :name => "index_string_proteins_on_stringdb_id", :unique => true
  add_index "string_proteins", ["taxon_id"], :name => "index_string_proteins_on_taxon_id"

  create_table "tag_has_objects", :force => true do |t|
    t.integer "tag_id"
    t.string  "object_type"
    t.integer "object_id"
  end

  add_index "tag_has_objects", ["object_id", "object_type"], :name => "index_tag_has_objects_on_object_id_and_object_type"
  add_index "tag_has_objects", ["object_id"], :name => "index_tag_has_objects_on_object_id"
  add_index "tag_has_objects", ["object_type"], :name => "index_tag_has_objects_on_object_type"
  add_index "tag_has_objects", ["tag_id", "object_id"], :name => "index_tag_has_objects_on_tag_id_and_object_id"
  add_index "tag_has_objects", ["tag_id", "object_type"], :name => "index_tag_has_objects_on_tag_id_and_object_type"
  add_index "tag_has_objects", ["tag_id"], :name => "index_tag_has_objects_on_tag_id"

  create_table "tags", :force => true do |t|
    t.string   "object_type",                 :null => false
    t.string   "category",                    :null => false
    t.string   "subcategory"
    t.string   "value",       :limit => 512,  :null => false
    t.string   "description", :limit => 2048
    t.datetime "created_at",                  :null => false
    t.datetime "updated_at",                  :null => false
  end

  add_index "tags", ["category"], :name => "index_tags_on_category"
  add_index "tags", ["description"], :name => "index_tags_on_description", :length => {"description"=>767}
  add_index "tags", ["object_type", "category", "subcategory", "value"], :name => "index_tags_on_object_type_and_category_and_subcategory_and_value", :unique => true
  add_index "tags", ["object_type"], :name => "index_tags_on_object_type"
  add_index "tags", ["subcategory"], :name => "index_tags_on_subcategory"
  add_index "tags", ["value"], :name => "index_tags_on_value"

  create_table "testdrop", :force => true do |t|
  end

  create_table "user_has_entity_groups", :force => true do |t|
    t.integer "user_id"
    t.integer "entity_group_id"
  end

  add_index "user_has_entity_groups", ["entity_group_id"], :name => "index_user_has_entity_groups_on_entity_group_id"
  add_index "user_has_entity_groups", ["user_id", "entity_group_id"], :name => "user_eg_index", :unique => true
  add_index "user_has_entity_groups", ["user_id"], :name => "index_user_has_entity_groups_on_user_id"

  create_table "users", :force => true do |t|
    t.string   "name",       :null => false
    t.string   "full_name"
    t.boolean  "is_admin"
    t.string   "email"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "users", ["name"], :name => "index_users_on_name", :unique => true

  create_table "variation_annotation_has_consequence", :force => true do |t|
    t.integer "variation_annotation_id"
    t.integer "consequence_id"
  end

  add_index "variation_annotation_has_consequence", ["consequence_id"], :name => "va_has_consequence_cons_id"
  add_index "variation_annotation_has_consequence", ["variation_annotation_id"], :name => "va_has_consequence_va_id"

  create_table "variation_annotations", :force => true do |t|
    t.integer  "variation_id",                           :null => false
    t.integer  "genetic_element_id",                     :null => false
    t.integer  "loss_of_function_id"
    t.integer  "organism_id"
    t.integer  "cdna_position"
    t.integer  "cds_position"
    t.integer  "protein_position"
    t.string   "amino_acids"
    t.string   "codons"
    t.string   "existing_variation"
    t.string   "exon"
    t.string   "intron"
    t.string   "motif_name"
    t.integer  "motif_pos"
    t.string   "sv"
    t.integer  "distance"
    t.string   "canonical"
    t.float    "sift_score"
    t.float    "polyphen_score"
    t.string   "gmaf"
    t.string   "domains"
    t.string   "ccds"
    t.string   "hgvsc"
    t.string   "hgvsp"
    t.float    "blosum62"
    t.text     "downstreamprotein"
    t.integer  "proteinlengthchange"
    t.text     "other_yaml"
    t.datetime "created_at",                             :null => false
    t.datetime "updated_at",                             :null => false
    t.boolean  "has_consequence",     :default => false
    t.float    "global_pop_freq"
    t.boolean  "high_inf_pos",        :default => false
    t.float    "motif_score_change",  :default => 0.0
  end

  add_index "variation_annotations", ["blosum62"], :name => "index_variation_annotations_on_blosum62"
  add_index "variation_annotations", ["canonical"], :name => "index_variation_annotations_on_canonical"
  add_index "variation_annotations", ["codons"], :name => "index_variation_annotations_on_codons"
  add_index "variation_annotations", ["domains"], :name => "index_variation_annotations_on_domains"
  add_index "variation_annotations", ["existing_variation"], :name => "index_variation_annotations_on_existing_variation"
  add_index "variation_annotations", ["exon"], :name => "index_variation_annotations_on_exon"
  add_index "variation_annotations", ["genetic_element_id"], :name => "index_variation_annotations_on_genetic_element_id"
  add_index "variation_annotations", ["global_pop_freq"], :name => "index_variation_annotations_on_global_pop_freq"
  add_index "variation_annotations", ["gmaf"], :name => "index_variation_annotations_on_gmaf"
  add_index "variation_annotations", ["has_consequence"], :name => "index_variation_annotations_on_has_consequence"
  add_index "variation_annotations", ["high_inf_pos"], :name => "index_variation_annotations_on_high_inf_pos"
  add_index "variation_annotations", ["intron"], :name => "index_variation_annotations_on_intron"
  add_index "variation_annotations", ["loss_of_function_id"], :name => "index_variation_annotations_on_loss_of_function_id"
  add_index "variation_annotations", ["motif_name"], :name => "index_variation_annotations_on_motif_name"
  add_index "variation_annotations", ["motif_score_change"], :name => "index_variation_annotations_on_motif_score_change"
  add_index "variation_annotations", ["organism_id"], :name => "index_variation_annotations_on_organism_id"
  add_index "variation_annotations", ["proteinlengthchange"], :name => "index_variation_annotations_on_proteinlengthchange"
  add_index "variation_annotations", ["sv"], :name => "index_variation_annotations_on_sv"
  add_index "variation_annotations", ["variation_id"], :name => "index_variation_annotations_on_variation_id"

  create_table "variation_call_has_variation_call_tag", :force => true do |t|
    t.integer "variation_call_id"
    t.integer "variation_call_tag_id"
  end

  create_table "variation_call_tags", :force => true do |t|
    t.string   "tag_name",                   :null => false
    t.string   "tag_value",  :limit => 2048, :null => false
    t.string   "tag_type",                   :null => false
    t.datetime "created_at",                 :null => false
    t.datetime "updated_at",                 :null => false
  end

  add_index "variation_call_tags", ["tag_name"], :name => "index_variation_call_tags_on_tag_name"
  add_index "variation_call_tags", ["tag_value"], :name => "index_variation_call_tags_on_tag_value", :length => {"tag_value"=>767}

  create_table "variation_calls", :force => true do |t|
    t.integer  "sample_id"
    t.integer  "variation_id"
    t.float    "qual"
    t.string   "filter"
    t.string   "gt"
    t.string   "ps"
    t.integer  "dp"
    t.float    "gl"
    t.float    "gq"
    t.datetime "created_at",                   :null => false
    t.datetime "updated_at",                   :null => false
    t.integer  "ref_reads",    :default => -1
    t.integer  "alt_reads",    :default => -1
    t.float    "cn"
    t.float    "cnl"
    t.float    "fs"
  end

  add_index "variation_calls", ["cn"], :name => "index_variation_calls_on_cn"
  add_index "variation_calls", ["cnl"], :name => "index_variation_calls_on_cnl"
  add_index "variation_calls", ["dp"], :name => "index_variation_calls_on_dp"
  add_index "variation_calls", ["filter"], :name => "index_variation_calls_on_filter"
  add_index "variation_calls", ["fs"], :name => "index_variation_calls_on_fs"
  add_index "variation_calls", ["gl"], :name => "index_variation_calls_on_gl"
  add_index "variation_calls", ["gq"], :name => "index_variation_calls_on_gq"
  add_index "variation_calls", ["gt"], :name => "index_variation_calls_on_gt"
  add_index "variation_calls", ["ps"], :name => "index_variation_calls_on_ps"
  add_index "variation_calls", ["qual"], :name => "index_variation_calls_on_qual"
  add_index "variation_calls", ["sample_id", "variation_id"], :name => "index_variation_calls_on_sample_id_and_variation_id", :unique => true
  add_index "variation_calls", ["sample_id"], :name => "index_variation_calls_on_sample_id"
  add_index "variation_calls", ["variation_id"], :name => "index_variation_calls_on_variation_id"

  create_table "variation_has_variation_tag", :force => true do |t|
    t.integer "variation_id"
    t.integer "variation_tag_id"
  end

  create_table "variation_tags", :force => true do |t|
    t.string   "tag_name",                   :null => false
    t.string   "tag_value",  :limit => 2048, :null => false
    t.string   "tag_type",                   :null => false
    t.datetime "created_at",                 :null => false
    t.datetime "updated_at",                 :null => false
  end

  add_index "variation_tags", ["tag_name"], :name => "index_variation_tags_on_tag_name"
  add_index "variation_tags", ["tag_value"], :name => "index_variation_tags_on_tag_value", :length => {"tag_value"=>767}

  create_table "variations", :force => true do |t|
    t.integer  "region_id"
    t.integer  "alteration_id"
    t.datetime "created_at",    :null => false
    t.datetime "updated_at",    :null => false
  end

  add_index "variations", ["alteration_id"], :name => "index_variations_on_alteration_id"
  add_index "variations", ["region_id", "alteration_id"], :name => "index_variations_on_region_id_and_alteration_id", :unique => true
  add_index "variations", ["region_id"], :name => "index_variations_on_region_id"

  create_table "vcf_file_indices", :force => true do |t|
    t.integer  "vcf_file_id",                                        :null => false
    t.binary   "index",       :limit => 16777215
    t.binary   "varlist",     :limit => 16777215
    t.boolean  "compressed",                      :default => true
    t.string   "format",                          :default => "bin"
    t.datetime "created_at",                                         :null => false
    t.datetime "updated_at",                                         :null => false
  end

  add_index "vcf_file_indices", ["vcf_file_id"], :name => "index_vcf_file_indices_on_vcf_file_id", :unique => true

  create_table "vcf_files", :force => true do |t|
    t.string   "name",                                                                 :null => false
    t.string   "filename",                                                             :null => false
    t.binary   "content",        :limit => 2147483647,                                 :null => false
    t.string   "md5checksum"
    t.string   "sample_names",                                                         :null => false
    t.string   "contact",                                                              :null => false
    t.string   "status",                               :default => "CREATED"
    t.integer  "institution_id"
    t.integer  "organism_id",                                                          :null => false
    t.datetime "created_at",                                                           :null => false
    t.datetime "updated_at",                                                           :null => false
    t.string   "type",                                 :default => "VcfFile"
    t.string   "filters",        :limit => 16384,      :default => "---\n:PASS: -1\n"
  end

  add_index "vcf_files", ["contact"], :name => "index_vcf_files_on_contact"
  add_index "vcf_files", ["filename"], :name => "index_vcf_files_on_filename"
  add_index "vcf_files", ["institution_id"], :name => "index_vcf_files_on_institution_id"
  add_index "vcf_files", ["md5checksum"], :name => "index_vcf_files_on_md5checksum", :unique => true
  add_index "vcf_files", ["name"], :name => "index_vcf_files_on_name"
  add_index "vcf_files", ["organism_id"], :name => "index_vcf_files_on_organism_id"
  add_index "vcf_files", ["sample_names"], :name => "index_vcf_files_on_sample_names"
  add_index "vcf_files", ["status"], :name => "index_vcf_files_on_status"
  add_index "vcf_files", ["type"], :name => "index_vcf_files_on_type"

  create_table "veps", :force => true do |t|
    t.integer  "variation_id",            :null => false
    t.integer  "organism_id",             :null => false
    t.string   "impact"
    t.string   "consequence",             :null => false
    t.string   "source"
    t.string   "biotype"
    t.string   "most_severe_consequence"
    t.string   "dbsnp"
    t.string   "dbsnp_allele"
    t.string   "minor_allele"
    t.float    "minor_allele_freq"
    t.string   "exac_adj_allele"
    t.float    "exac_adj_maf"
    t.string   "gene_id"
    t.string   "transcript_id"
    t.string   "gene_symbol"
    t.string   "ccds"
    t.integer  "cdna_start"
    t.integer  "cdna_end"
    t.integer  "cds_start"
    t.integer  "cds_end"
    t.boolean  "canonical"
    t.string   "protein_id"
    t.integer  "protein_start"
    t.integer  "protein_end"
    t.string   "amino_acids"
    t.string   "codons"
    t.string   "numbers"
    t.string   "hgvsc"
    t.string   "hgvsp"
    t.integer  "distance"
    t.string   "trembl_id"
    t.string   "uniparc"
    t.string   "swissprot"
    t.string   "polyphen_prediction"
    t.float    "polyphen_score"
    t.string   "sift_prediction"
    t.float    "sift_score"
    t.string   "domains"
    t.boolean  "somatic"
    t.boolean  "gene_pheno"
    t.boolean  "phenotype_or_disease"
    t.boolean  "allele_is_minor"
    t.string   "motif_feature_id"
    t.string   "motif_name"
    t.string   "high_inf_pos"
    t.integer  "motif_pos"
    t.float    "motif_score_change"
    t.datetime "created_at",              :null => false
    t.datetime "updated_at",              :null => false
  end

  add_index "veps", ["allele_is_minor"], :name => "index_veps_on_allele_is_minor"
  add_index "veps", ["amino_acids"], :name => "index_veps_on_amino_acids"
  add_index "veps", ["biotype"], :name => "index_veps_on_biotype"
  add_index "veps", ["canonical"], :name => "index_veps_on_canonical"
  add_index "veps", ["ccds"], :name => "index_veps_on_ccds"
  add_index "veps", ["cdna_end"], :name => "index_veps_on_cdna_end"
  add_index "veps", ["cdna_start"], :name => "index_veps_on_cdna_start"
  add_index "veps", ["cds_end"], :name => "index_veps_on_cds_end"
  add_index "veps", ["cds_start"], :name => "index_veps_on_cds_start"
  add_index "veps", ["codons"], :name => "index_veps_on_codons"
  add_index "veps", ["consequence"], :name => "index_veps_on_consequence"
  add_index "veps", ["dbsnp"], :name => "index_veps_on_dbsnp"
  add_index "veps", ["dbsnp_allele"], :name => "index_veps_on_dbsnp_allele"
  add_index "veps", ["distance"], :name => "index_veps_on_distance"
  add_index "veps", ["domains"], :name => "index_veps_on_domains"
  add_index "veps", ["exac_adj_allele"], :name => "index_veps_on_exac_adj_allele"
  add_index "veps", ["exac_adj_maf"], :name => "index_veps_on_exac_adj_maf"
  add_index "veps", ["gene_id"], :name => "index_veps_on_gene_id"
  add_index "veps", ["gene_pheno"], :name => "index_veps_on_gene_pheno"
  add_index "veps", ["gene_symbol"], :name => "index_veps_on_gene_symbol"
  add_index "veps", ["hgvsc"], :name => "index_veps_on_hgvsc"
  add_index "veps", ["hgvsp"], :name => "index_veps_on_hgvsp"
  add_index "veps", ["high_inf_pos"], :name => "index_veps_on_high_inf_pos"
  add_index "veps", ["impact"], :name => "index_veps_on_impact"
  add_index "veps", ["minor_allele"], :name => "index_veps_on_minor_allele"
  add_index "veps", ["minor_allele_freq"], :name => "index_veps_on_minor_allele_freq"
  add_index "veps", ["most_severe_consequence"], :name => "index_veps_on_most_severe_consequence"
  add_index "veps", ["motif_feature_id"], :name => "index_veps_on_motif_feature_id"
  add_index "veps", ["motif_name"], :name => "index_veps_on_motif_name"
  add_index "veps", ["motif_pos"], :name => "index_veps_on_motif_pos"
  add_index "veps", ["motif_score_change"], :name => "index_veps_on_motif_score_change"
  add_index "veps", ["numbers"], :name => "index_veps_on_numbers"
  add_index "veps", ["organism_id"], :name => "index_veps_on_organism_id"
  add_index "veps", ["phenotype_or_disease"], :name => "index_veps_on_phenotype_or_disease"
  add_index "veps", ["polyphen_prediction"], :name => "index_veps_on_polyphen_prediction"
  add_index "veps", ["polyphen_score"], :name => "index_veps_on_polyphen_score"
  add_index "veps", ["protein_end"], :name => "index_veps_on_protein_end"
  add_index "veps", ["protein_id"], :name => "index_veps_on_protein_id"
  add_index "veps", ["protein_start"], :name => "index_veps_on_protein_start"
  add_index "veps", ["sift_prediction"], :name => "index_veps_on_sift_prediction"
  add_index "veps", ["sift_score"], :name => "index_veps_on_sift_score"
  add_index "veps", ["somatic"], :name => "index_veps_on_somatic"
  add_index "veps", ["source"], :name => "index_veps_on_source"
  add_index "veps", ["swissprot"], :name => "index_veps_on_swissprot"
  add_index "veps", ["transcript_id"], :name => "index_veps_on_transcript_id"
  add_index "veps", ["trembl_id"], :name => "index_veps_on_trembl_id"
  add_index "veps", ["uniparc"], :name => "index_veps_on_uniparc"
  add_index "veps", ["variation_id"], :name => "index_veps_on_variation_id"

  create_table "veps_v75s", :force => true do |t|
    t.integer  "variation_id",                            :null => false
    t.integer  "organism_id",                             :null => false
    t.string   "impact"
    t.string   "consequence",                             :null => false
    t.string   "source"
    t.string   "biotype"
    t.string   "most_severe_consequence"
    t.string   "dbsnp",                   :limit => 1024
    t.string   "dbsnp_allele",            :limit => 1024
    t.string   "minor_allele"
    t.float    "minor_allele_freq"
    t.string   "exac_adj_allele"
    t.float    "exac_adj_maf"
    t.string   "gene_id"
    t.string   "transcript_id"
    t.string   "gene_symbol"
    t.string   "ccds"
    t.integer  "cdna_start"
    t.integer  "cdna_end"
    t.integer  "cds_start"
    t.integer  "cds_end"
    t.boolean  "canonical"
    t.string   "protein_id"
    t.integer  "protein_start"
    t.integer  "protein_end"
    t.string   "amino_acids"
    t.string   "codons"
    t.integer  "numbers1"
    t.integer  "numbers2"
    t.string   "hgvsc"
    t.string   "hgvsp"
    t.integer  "hgvs_offset"
    t.integer  "distance"
    t.string   "trembl_id"
    t.string   "uniparc"
    t.string   "swissprot"
    t.string   "polyphen_prediction",     :limit => 32
    t.float    "polyphen_score"
    t.string   "sift_prediction",         :limit => 32
    t.float    "sift_score"
    t.string   "domains",                 :limit => 2048
    t.string   "pubmed",                  :limit => 2048
    t.boolean  "somatic"
    t.boolean  "gene_pheno"
    t.boolean  "phenotype_or_disease"
    t.boolean  "allele_is_minor"
    t.string   "clin_sig",                :limit => 2048
    t.string   "motif_feature_id"
    t.string   "motif_name"
    t.boolean  "high_inf_pos"
    t.integer  "motif_pos"
    t.float    "motif_score_change"
    t.datetime "created_at",                              :null => false
    t.datetime "updated_at",                              :null => false
  end

  add_index "veps_v75s", ["allele_is_minor"], :name => "index_veps_v75s_on_allele_is_minor"
  add_index "veps_v75s", ["amino_acids"], :name => "index_veps_v75s_on_amino_acids"
  add_index "veps_v75s", ["biotype"], :name => "index_veps_v75s_on_biotype"
  add_index "veps_v75s", ["canonical"], :name => "index_veps_v75s_on_canonical"
  add_index "veps_v75s", ["ccds"], :name => "index_veps_v75s_on_ccds"
  add_index "veps_v75s", ["cdna_end"], :name => "index_veps_v75s_on_cdna_end"
  add_index "veps_v75s", ["cdna_start"], :name => "index_veps_v75s_on_cdna_start"
  add_index "veps_v75s", ["cds_end"], :name => "index_veps_v75s_on_cds_end"
  add_index "veps_v75s", ["cds_start"], :name => "index_veps_v75s_on_cds_start"
  add_index "veps_v75s", ["codons"], :name => "index_veps_v75s_on_codons"
  add_index "veps_v75s", ["consequence"], :name => "index_veps_v75s_on_consequence"
  add_index "veps_v75s", ["dbsnp"], :name => "index_veps_v75s_on_dbsnp", :length => {"dbsnp"=>767}
  add_index "veps_v75s", ["dbsnp_allele"], :name => "index_veps_v75s_on_dbsnp_allele", :length => {"dbsnp_allele"=>767}
  add_index "veps_v75s", ["distance"], :name => "index_veps_v75s_on_distance"
  add_index "veps_v75s", ["domains"], :name => "index_veps_v75s_on_domains", :length => {"domains"=>767}
  add_index "veps_v75s", ["exac_adj_allele"], :name => "index_veps_v75s_on_exac_adj_allele"
  add_index "veps_v75s", ["exac_adj_maf"], :name => "index_veps_v75s_on_exac_adj_maf"
  add_index "veps_v75s", ["gene_id"], :name => "index_veps_v75s_on_gene_id"
  add_index "veps_v75s", ["gene_pheno"], :name => "index_veps_v75s_on_gene_pheno"
  add_index "veps_v75s", ["gene_symbol"], :name => "index_veps_v75s_on_gene_symbol"
  add_index "veps_v75s", ["hgvs_offset"], :name => "index_veps_v75s_on_hgvs_offset"
  add_index "veps_v75s", ["hgvsc"], :name => "index_veps_v75s_on_hgvsc"
  add_index "veps_v75s", ["hgvsp"], :name => "index_veps_v75s_on_hgvsp"
  add_index "veps_v75s", ["high_inf_pos"], :name => "index_veps_v75s_on_high_inf_pos"
  add_index "veps_v75s", ["impact"], :name => "index_veps_v75s_on_impact"
  add_index "veps_v75s", ["minor_allele"], :name => "index_veps_v75s_on_minor_allele"
  add_index "veps_v75s", ["minor_allele_freq"], :name => "index_veps_v75s_on_minor_allele_freq"
  add_index "veps_v75s", ["most_severe_consequence"], :name => "index_veps_v75s_on_most_severe_consequence"
  add_index "veps_v75s", ["motif_feature_id"], :name => "index_veps_v75s_on_motif_feature_id"
  add_index "veps_v75s", ["motif_name"], :name => "index_veps_v75s_on_motif_name"
  add_index "veps_v75s", ["motif_pos"], :name => "index_veps_v75s_on_motif_pos"
  add_index "veps_v75s", ["motif_score_change"], :name => "index_veps_v75s_on_motif_score_change"
  add_index "veps_v75s", ["numbers1"], :name => "index_veps_v75s_on_numbers1"
  add_index "veps_v75s", ["numbers2"], :name => "index_veps_v75s_on_numbers2"
  add_index "veps_v75s", ["organism_id"], :name => "index_veps_v75s_on_organism_id"
  add_index "veps_v75s", ["phenotype_or_disease"], :name => "index_veps_v75s_on_phenotype_or_disease"
  add_index "veps_v75s", ["polyphen_prediction"], :name => "index_veps_v75s_on_polyphen_prediction"
  add_index "veps_v75s", ["polyphen_score"], :name => "index_veps_v75s_on_polyphen_score"
  add_index "veps_v75s", ["protein_end"], :name => "index_veps_v75s_on_protein_end"
  add_index "veps_v75s", ["protein_id"], :name => "index_veps_v75s_on_protein_id"
  add_index "veps_v75s", ["protein_start"], :name => "index_veps_v75s_on_protein_start"
  add_index "veps_v75s", ["pubmed"], :name => "index_veps_v75s_on_pubmed", :length => {"pubmed"=>767}
  add_index "veps_v75s", ["sift_prediction"], :name => "index_veps_v75s_on_sift_prediction"
  add_index "veps_v75s", ["sift_score"], :name => "index_veps_v75s_on_sift_score"
  add_index "veps_v75s", ["somatic"], :name => "index_veps_v75s_on_somatic"
  add_index "veps_v75s", ["source"], :name => "index_veps_v75s_on_source"
  add_index "veps_v75s", ["swissprot"], :name => "index_veps_v75s_on_swissprot"
  add_index "veps_v75s", ["transcript_id"], :name => "index_veps_v75s_on_transcript_id"
  add_index "veps_v75s", ["trembl_id"], :name => "index_veps_v75s_on_trembl_id"
  add_index "veps_v75s", ["uniparc"], :name => "index_veps_v75s_on_uniparc"
  add_index "veps_v75s", ["variation_id", "organism_id", "source"], :name => "index_veps_v75s_on_variation_id_and_organism_id_and_source"
  add_index "veps_v75s", ["variation_id"], :name => "index_veps_v75s_on_variation_id"

  create_table "veps_v83s", :force => true do |t|
    t.integer  "variation_id",                            :null => false
    t.integer  "organism_id",                             :null => false
    t.string   "impact"
    t.string   "consequence",                             :null => false
    t.string   "source"
    t.string   "biotype"
    t.string   "most_severe_consequence"
    t.string   "dbsnp"
    t.string   "dbsnp_allele"
    t.string   "minor_allele"
    t.float    "minor_allele_freq"
    t.string   "exac_adj_allele"
    t.float    "exac_adj_maf"
    t.string   "gene_id"
    t.string   "transcript_id"
    t.string   "gene_symbol"
    t.string   "ccds"
    t.integer  "cdna_start"
    t.integer  "cdna_end"
    t.integer  "cds_start"
    t.integer  "cds_end"
    t.boolean  "canonical"
    t.string   "protein_id"
    t.integer  "protein_start"
    t.integer  "protein_end"
    t.string   "amino_acids"
    t.string   "codons"
    t.string   "numbers"
    t.string   "hgvsc"
    t.string   "hgvsp"
    t.integer  "distance"
    t.string   "trembl_id",               :limit => 2048
    t.string   "uniparc",                 :limit => 2048
    t.string   "swissprot",               :limit => 2048
    t.string   "polyphen_prediction"
    t.float    "polyphen_score"
    t.string   "sift_prediction"
    t.float    "sift_score"
    t.string   "domains",                 :limit => 2048
    t.string   "pubmed",                  :limit => 2048
    t.boolean  "somatic"
    t.boolean  "gene_pheno"
    t.boolean  "phenotype_or_disease"
    t.boolean  "allele_is_minor"
    t.string   "clin_sig",                :limit => 2048
    t.string   "motif_feature_id"
    t.string   "motif_name"
    t.boolean  "high_inf_pos"
    t.integer  "motif_pos"
    t.float    "motif_score_change"
    t.datetime "created_at",                              :null => false
    t.datetime "updated_at",                              :null => false
  end

  add_index "veps_v83s", ["allele_is_minor"], :name => "index_veps_v83s_on_allele_is_minor"
  add_index "veps_v83s", ["amino_acids"], :name => "index_veps_v83s_on_amino_acids"
  add_index "veps_v83s", ["biotype"], :name => "index_veps_v83s_on_biotype"
  add_index "veps_v83s", ["canonical"], :name => "index_veps_v83s_on_canonical"
  add_index "veps_v83s", ["ccds"], :name => "index_veps_v83s_on_ccds"
  add_index "veps_v83s", ["cdna_end"], :name => "index_veps_v83s_on_cdna_end"
  add_index "veps_v83s", ["cdna_start"], :name => "index_veps_v83s_on_cdna_start"
  add_index "veps_v83s", ["cds_end"], :name => "index_veps_v83s_on_cds_end"
  add_index "veps_v83s", ["cds_start"], :name => "index_veps_v83s_on_cds_start"
  add_index "veps_v83s", ["codons"], :name => "index_veps_v83s_on_codons"
  add_index "veps_v83s", ["consequence"], :name => "index_veps_v83s_on_consequence"
  add_index "veps_v83s", ["dbsnp"], :name => "index_veps_v83s_on_dbsnp"
  add_index "veps_v83s", ["dbsnp_allele"], :name => "index_veps_v83s_on_dbsnp_allele"
  add_index "veps_v83s", ["distance"], :name => "index_veps_v83s_on_distance"
  add_index "veps_v83s", ["domains"], :name => "index_veps_v83s_on_domains", :length => {"domains"=>767}
  add_index "veps_v83s", ["exac_adj_allele"], :name => "index_veps_v83s_on_exac_adj_allele"
  add_index "veps_v83s", ["exac_adj_maf"], :name => "index_veps_v83s_on_exac_adj_maf"
  add_index "veps_v83s", ["gene_id"], :name => "index_veps_v83s_on_gene_id"
  add_index "veps_v83s", ["gene_pheno"], :name => "index_veps_v83s_on_gene_pheno"
  add_index "veps_v83s", ["gene_symbol"], :name => "index_veps_v83s_on_gene_symbol"
  add_index "veps_v83s", ["hgvsc"], :name => "index_veps_v83s_on_hgvsc"
  add_index "veps_v83s", ["hgvsp"], :name => "index_veps_v83s_on_hgvsp"
  add_index "veps_v83s", ["high_inf_pos"], :name => "index_veps_v83s_on_high_inf_pos"
  add_index "veps_v83s", ["impact"], :name => "index_veps_v83s_on_impact"
  add_index "veps_v83s", ["minor_allele"], :name => "index_veps_v83s_on_minor_allele"
  add_index "veps_v83s", ["minor_allele_freq"], :name => "index_veps_v83s_on_minor_allele_freq"
  add_index "veps_v83s", ["most_severe_consequence"], :name => "index_veps_v83s_on_most_severe_consequence"
  add_index "veps_v83s", ["motif_feature_id"], :name => "index_veps_v83s_on_motif_feature_id"
  add_index "veps_v83s", ["motif_name"], :name => "index_veps_v83s_on_motif_name"
  add_index "veps_v83s", ["motif_pos"], :name => "index_veps_v83s_on_motif_pos"
  add_index "veps_v83s", ["motif_score_change"], :name => "index_veps_v83s_on_motif_score_change"
  add_index "veps_v83s", ["numbers"], :name => "index_veps_v83s_on_numbers"
  add_index "veps_v83s", ["organism_id"], :name => "index_veps_v83s_on_organism_id"
  add_index "veps_v83s", ["phenotype_or_disease"], :name => "index_veps_v83s_on_phenotype_or_disease"
  add_index "veps_v83s", ["polyphen_prediction"], :name => "index_veps_v83s_on_polyphen_prediction"
  add_index "veps_v83s", ["polyphen_score"], :name => "index_veps_v83s_on_polyphen_score"
  add_index "veps_v83s", ["protein_end"], :name => "index_veps_v83s_on_protein_end"
  add_index "veps_v83s", ["protein_id"], :name => "index_veps_v83s_on_protein_id"
  add_index "veps_v83s", ["protein_start"], :name => "index_veps_v83s_on_protein_start"
  add_index "veps_v83s", ["pubmed"], :name => "index_veps_v83s_on_pubmed", :length => {"pubmed"=>767}
  add_index "veps_v83s", ["sift_prediction"], :name => "index_veps_v83s_on_sift_prediction"
  add_index "veps_v83s", ["sift_score"], :name => "index_veps_v83s_on_sift_score"
  add_index "veps_v83s", ["somatic"], :name => "index_veps_v83s_on_somatic"
  add_index "veps_v83s", ["source"], :name => "index_veps_v83s_on_source"
  add_index "veps_v83s", ["swissprot"], :name => "index_veps_v83s_on_swissprot", :length => {"swissprot"=>767}
  add_index "veps_v83s", ["transcript_id"], :name => "index_veps_v83s_on_transcript_id"
  add_index "veps_v83s", ["trembl_id"], :name => "index_veps_v83s_on_trembl_id", :length => {"trembl_id"=>767}
  add_index "veps_v83s", ["uniparc"], :name => "index_veps_v83s_on_uniparc", :length => {"uniparc"=>767}
  add_index "veps_v83s", ["variation_id", "organism_id", "source"], :name => "index_veps_v83s_on_variation_id_and_organism_id_and_source"
  add_index "veps_v83s", ["variation_id"], :name => "index_veps_v83s_on_variation_id"

  create_table "veps_v84s", :force => true do |t|
    t.integer  "variation_id",                            :null => false
    t.integer  "organism_id",                             :null => false
    t.string   "impact"
    t.string   "consequence",                             :null => false
    t.string   "source"
    t.string   "biotype"
    t.string   "most_severe_consequence"
    t.string   "dbsnp",                   :limit => 1024
    t.string   "dbsnp_allele",            :limit => 1024
    t.string   "minor_allele"
    t.float    "minor_allele_freq"
    t.string   "exac_adj_allele"
    t.float    "exac_adj_maf"
    t.string   "gene_id"
    t.string   "transcript_id"
    t.string   "gene_symbol"
    t.string   "ccds"
    t.integer  "cdna_start"
    t.integer  "cdna_end"
    t.integer  "cds_start"
    t.integer  "cds_end"
    t.boolean  "canonical"
    t.string   "protein_id"
    t.integer  "protein_start"
    t.integer  "protein_end"
    t.string   "amino_acids"
    t.string   "codons"
    t.float    "numbers1"
    t.float    "numbers2"
    t.string   "hgvsc"
    t.string   "hgvsp"
    t.integer  "hgvs_offset"
    t.integer  "distance"
    t.string   "trembl_id"
    t.string   "uniparc"
    t.string   "swissprot"
    t.string   "polyphen_prediction",     :limit => 32
    t.float    "polyphen_score"
    t.string   "sift_prediction",         :limit => 32
    t.float    "sift_score"
    t.string   "domains",                 :limit => 2048
    t.string   "pubmed",                  :limit => 2048
    t.boolean  "somatic"
    t.boolean  "gene_pheno"
    t.boolean  "phenotype_or_disease"
    t.boolean  "allele_is_minor"
    t.string   "clin_sig",                :limit => 2048
    t.string   "motif_feature_id"
    t.string   "motif_name"
    t.boolean  "high_inf_pos"
    t.integer  "motif_pos"
    t.float    "motif_score_change"
    t.datetime "created_at",                              :null => false
    t.datetime "updated_at",                              :null => false
    t.integer  "bp_overlap"
    t.float    "percentage_overlap"
  end

  add_index "veps_v84s", ["allele_is_minor"], :name => "index_veps_v84s_on_allele_is_minor"
  add_index "veps_v84s", ["amino_acids"], :name => "index_veps_v84s_on_amino_acids"
  add_index "veps_v84s", ["biotype"], :name => "index_veps_v84s_on_biotype"
  add_index "veps_v84s", ["bp_overlap"], :name => "bp_overlap"
  add_index "veps_v84s", ["canonical"], :name => "index_veps_v84s_on_canonical"
  add_index "veps_v84s", ["ccds"], :name => "index_veps_v84s_on_ccds"
  add_index "veps_v84s", ["cdna_end"], :name => "index_veps_v84s_on_cdna_end"
  add_index "veps_v84s", ["cdna_start"], :name => "index_veps_v84s_on_cdna_start"
  add_index "veps_v84s", ["cds_end"], :name => "index_veps_v84s_on_cds_end"
  add_index "veps_v84s", ["cds_start"], :name => "index_veps_v84s_on_cds_start"
  add_index "veps_v84s", ["codons"], :name => "index_veps_v84s_on_codons"
  add_index "veps_v84s", ["consequence"], :name => "index_veps_v84s_on_consequence"
  add_index "veps_v84s", ["dbsnp"], :name => "index_veps_v84s_on_dbsnp", :length => {"dbsnp"=>767}
  add_index "veps_v84s", ["dbsnp_allele"], :name => "index_veps_v84s_on_dbsnp_allele", :length => {"dbsnp_allele"=>767}
  add_index "veps_v84s", ["distance"], :name => "index_veps_v84s_on_distance"
  add_index "veps_v84s", ["domains"], :name => "index_veps_v84s_on_domains", :length => {"domains"=>767}
  add_index "veps_v84s", ["exac_adj_allele"], :name => "index_veps_v84s_on_exac_adj_allele"
  add_index "veps_v84s", ["exac_adj_maf"], :name => "index_veps_v84s_on_exac_adj_maf"
  add_index "veps_v84s", ["gene_id"], :name => "index_veps_v84s_on_gene_id"
  add_index "veps_v84s", ["gene_pheno"], :name => "index_veps_v84s_on_gene_pheno"
  add_index "veps_v84s", ["gene_symbol"], :name => "index_veps_v84s_on_gene_symbol"
  add_index "veps_v84s", ["hgvs_offset"], :name => "index_veps_v84s_on_hgvs_offset"
  add_index "veps_v84s", ["hgvsc"], :name => "index_veps_v84s_on_hgvsc"
  add_index "veps_v84s", ["hgvsp"], :name => "index_veps_v84s_on_hgvsp"
  add_index "veps_v84s", ["high_inf_pos"], :name => "index_veps_v84s_on_high_inf_pos"
  add_index "veps_v84s", ["impact"], :name => "index_veps_v84s_on_impact"
  add_index "veps_v84s", ["minor_allele"], :name => "index_veps_v84s_on_minor_allele"
  add_index "veps_v84s", ["minor_allele_freq"], :name => "index_veps_v84s_on_minor_allele_freq"
  add_index "veps_v84s", ["most_severe_consequence"], :name => "index_veps_v84s_on_most_severe_consequence"
  add_index "veps_v84s", ["motif_feature_id"], :name => "index_veps_v84s_on_motif_feature_id"
  add_index "veps_v84s", ["motif_name"], :name => "index_veps_v84s_on_motif_name"
  add_index "veps_v84s", ["motif_pos"], :name => "index_veps_v84s_on_motif_pos"
  add_index "veps_v84s", ["motif_score_change"], :name => "index_veps_v84s_on_motif_score_change"
  add_index "veps_v84s", ["numbers1"], :name => "index_veps_v84s_on_numbers1"
  add_index "veps_v84s", ["numbers2"], :name => "index_veps_v84s_on_numbers2"
  add_index "veps_v84s", ["organism_id"], :name => "index_veps_v84s_on_organism_id"
  add_index "veps_v84s", ["percentage_overlap"], :name => "percentage_overlap"
  add_index "veps_v84s", ["phenotype_or_disease"], :name => "index_veps_v84s_on_phenotype_or_disease"
  add_index "veps_v84s", ["polyphen_prediction"], :name => "index_veps_v84s_on_polyphen_prediction"
  add_index "veps_v84s", ["polyphen_score"], :name => "index_veps_v84s_on_polyphen_score"
  add_index "veps_v84s", ["protein_end"], :name => "index_veps_v84s_on_protein_end"
  add_index "veps_v84s", ["protein_id"], :name => "index_veps_v84s_on_protein_id"
  add_index "veps_v84s", ["protein_start"], :name => "index_veps_v84s_on_protein_start"
  add_index "veps_v84s", ["pubmed"], :name => "index_veps_v84s_on_pubmed", :length => {"pubmed"=>767}
  add_index "veps_v84s", ["sift_prediction"], :name => "index_veps_v84s_on_sift_prediction"
  add_index "veps_v84s", ["sift_score"], :name => "index_veps_v84s_on_sift_score"
  add_index "veps_v84s", ["somatic"], :name => "index_veps_v84s_on_somatic"
  add_index "veps_v84s", ["source"], :name => "index_veps_v84s_on_source"
  add_index "veps_v84s", ["swissprot"], :name => "index_veps_v84s_on_swissprot"
  add_index "veps_v84s", ["transcript_id"], :name => "index_veps_v84s_on_transcript_id"
  add_index "veps_v84s", ["trembl_id"], :name => "index_veps_v84s_on_trembl_id"
  add_index "veps_v84s", ["uniparc"], :name => "index_veps_v84s_on_uniparc"
  add_index "veps_v84s", ["variation_id", "organism_id", "source"], :name => "index_veps_v84s_on_variation_id_and_organism_id_and_source"
  add_index "veps_v84s", ["variation_id"], :name => "index_veps_v84s_on_variation_id"

end
