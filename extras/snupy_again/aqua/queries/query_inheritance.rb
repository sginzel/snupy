class QueryInheritance < SimpleQuery
	register_query :combined_inheritance_pattern,
	               label: "Combined inheritance patterns",
	               default: false,
	               type: :checkbox,
	               tooltip: "Please select the desired inheritance patterns from the list of filters.",
	               organism: [organisms(:human), organisms(:mouse)],
	               priority: 20.1,
	               combine: "OR",
	               group: "Inheritance"
	
	register_query :inheritance_autosomal_recessive,
	               label: "Recessive",
	               default: false,
	               type: :checkbox,
	               tooltip: "Reduce variants to those that follow autosomal recessive mode of inheritance.",
	               organism: [organisms(:human), organisms(:mouse)],
	               priority: 20,
	               group: "Inheritance"
	
	register_query :inheritance_autosomal_dominant,
	               label: "Dominant",
	               default: false,
	               type: :checkbox,
	               tooltip: "Reduce variants to those that follow autosomal dominant mode of inheritance. IMPORTANT: REQUIRES FATHER OR MOTHER TO CARRY A [DISEASE] TAG",
	               organism: [organisms(:human), organisms(:mouse)],
	               priority: 20,
	               group: "Inheritance"
	
	register_query :inheritance_denovo,
	               label: "Denovo",
	               default: false,
	               type: :checkbox,
	               tooltip: "Reduce variants to those not explained by inheritance (takes all variants of parents into account)",
	               organism: [organisms(:human), organisms(:mouse)],
	               priority: 20,
	               group: "Inheritance"
	
	register_query :inheritance_compound_heterozygous,
	               label: "Compound heterozygous in parents",
	               default: false,
	               type: :checkbox,
	               tooltip: "Retrieved variants which are also heterozygous in all these samples.",
	               combine: "AND",
	               organism: [organisms(:human), organisms(:mouse)],
	               priority: 22,
	               group: "Inheritance"
	

end