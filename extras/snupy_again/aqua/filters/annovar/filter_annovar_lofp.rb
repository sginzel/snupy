class FilterAnnovarLofp < SimpleFilter
	create_filter_for QueryLossOfFunction, :loss_of_function,
						name: :annovar_polyphen_humvar, 
						label: "PolyPhen2 HumVar",
						filter_method: :polyphen_humvar,
						organism: [organisms(:human)],
						checked: true,
						requires: {
							Annovar => [:polyphen2_hvar_pred]
						},
						tool: AnnovarAnnotation
						
	create_filter_for QueryLossOfFunction, :loss_of_function,
						name: :annovar_polyphen_hdvi, 
						label: "PolyPhen2 HumDiv",
						filter_method: :polyphen_hdvi,
						organism: [organisms(:human)],
						checked: true,
						requires: {
							Annovar => [:polyphen2_hdvi_pred]
						},
						tool: AnnovarAnnotation
						
	create_filter_for QueryLossOfFunction, :loss_of_function,
						name: :annovar_sift, 
						label: "SIFT",
						filter_method: :sift,
						organism: [organisms(:human)],
						checked: true,
						requires: {
							Annovar => [:sift_pred]
						},
						tool: AnnovarAnnotation
						
	create_filter_for QueryLossOfFunction, :loss_of_function,
						name: :annovar_mutation_taster, 
						label: "MutationTaster",
						filter_method: :mutation_taster,
						organism: [organisms(:human)],
						checked: true,
						requires: {
							Annovar => [:mutation_taster_pred]
						},
						tool: AnnovarAnnotation
						
	create_filter_for QueryLossOfFunction, :loss_of_function,
						name: :annovar_mutation_assessor, 
						label: "MutationAssessor",
						filter_method: :mutation_assessor,
						organism: [organisms(:human)],
						checked: true,
						requires: {
							Annovar => [:mutation_assessor_pred]
						},
						tool: AnnovarAnnotation
						
	create_filter_for QueryLossOfFunction, :loss_of_function,
						name: :annovar_fathmm, 
						label: "FatHMM",
						filter_method: :fathmm,
						organism: [organisms(:human)],
						checked: true,
						requires: {
							Annovar => [:fathmm_pred]
						},
						tool: AnnovarAnnotation
						
	create_filter_for QueryLossOfFunction, :loss_of_function,
						name: :annovar_radial_svm, 
						label: "Radial SVM",
						filter_method: :radial_svm,
						organism: [organisms(:human)],
						checked: true,
						requires: {
							Annovar => [:radial_svm_pred]
						},
						tool: AnnovarAnnotation
						
	create_filter_for QueryLossOfFunction, :loss_of_function,
						name: :annovar_lr, 
						label: "MetaLR",
						filter_method: :lr,
						organism: [organisms(:human)],
						checked: true,
						requires: {
							Annovar => [:lr_pred]
						},
						tool: AnnovarAnnotation
						
	create_filter_for QueryLossOfFunction, :loss_of_function,
						name: :annovar_vest3, 
						label: "VEST3 (>0.9)",
						filter_method: :vest3,
						organism: [organisms(:human)],
						checked: true,
						requires: {
							Annovar => [:vest3_score]
						},
						tool: AnnovarAnnotation
	
		create_filter_for QueryLossOfFunction, :loss_of_function,
						name: :annovar_Cadd10, 
						label: "CADD 10%",
						filter_method: :cadd10,
						organism: [organisms(:human)],
						checked: false,
						requires: {
							Annovar => [:cadd_phred]
						},
						tool: AnnovarAnnotation
		create_filter_for QueryLossOfFunction, :loss_of_function,
						name: :annovar_Cadd1, 
						label: "CADD 1%",
						filter_method: :cadd1,
						organism: [organisms(:human)],
						checked: true,
						requires: {
							Annovar => [:cadd_phred]
						},
						tool: AnnovarAnnotation
		create_filter_for QueryLossOfFunction, :loss_of_function,
						name: :annovar_Caddtop, 
						label: "Most impactful CADD scores in selected samples (10%)",
						filter_method: :cadd_top10,
						organism: [organisms(:human)],
						checked: true,
						requires: {
							Annovar => [:cadd_phred]
						},
						tool: AnnovarAnnotation
						
	def polyphen_humvar(value)
		"annovars.polyphen2_hvar_pred = 'D'"
	end
	
	def polyphen_hdvi(value)
		"annovars.polyphen2_hdvi_pred = 'D'"
	end
	
	def sift(value)
		"annovars.sift_pred = 'D'"
	end
	
	def mutation_taster(value)
		"annovars.mutation_taster_pred = 'D'"
	end
	
	def mutation_assessor(value)
		"annovars.mutation_assessor_pred IN ('M', 'H') "
	end
	
	def fathmm(value)
		"annovars.fathmm_pred = 'D'"
	end
	
	def radial_svm(value)
		"annovars.radial_svm_pred = 'D'"
	end
	
	def lr(value)
		"annovars.lr_pred = 'D'"
	end
	
	def vest3(value)
		"annovars.vest3_score > 0.9"
	end
	
	def cadd(value)
		"annovars.cadd_phred >= #{value}"
	end
	
	def cadd10(value)
		cadd(10)
	end
	
	def cadd1(value)
		cadd(20)
	end
	
	def cadd_top10(value, params)
		# find all CADD scores of variants of the selected samples
		smpls = (params[:samples] || params["samples"])
		return nil if smpls.size == 0
		cadds = Annovar.joins(:samples)
			.where("samples.id" => params[:samples])
			.where("cadd_phred IS NOT NULL")
			.pluck(:cadd_phred).sort
		cadd_cutoff = cadds[(cadds.size * 0.9).to_i]
		"annovars.cadd_phred >= #{cadd_cutoff} OR annovars.cadd_phred IS NULL"
	end
	
end