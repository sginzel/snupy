class QueryConsequence < SimpleQuery
	register_query :consequence, 
								 label: "Consequence",
								 default: %w(frameshift_variant
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
														TFBS_ablation), 
								 type: :collection,
								 combine: "OR",
								 tooltip: "Predicted effect of variants.",
								 organism: [organisms(:human), organisms(:mouse)], 
								 priority: 15,
								 group: "Basic"
end