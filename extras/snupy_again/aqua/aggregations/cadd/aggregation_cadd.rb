class AggregationCadd < Aggregation

	register_aggregation :lofp,
											 label: "CADD Scores",
											 colname: "CADD",
											 colindex: 8.0,
											 aggregation_method: :aggregate_requirements,
											 type: :attribute,
											 checked: true,
											 category: "CADD",
											 color: {
													 "CADD[phred]" => create_color_gradient([0,10,20,50], colors = ["palegreen", "lightyellow", "salmon", "indianred"])
											 },
											 requires: {
													 Cadd => [:phred, :raw]
											 }
	register_aggregation :cadd_summary,
	                     label:              "Summary",
	                     colname:            "CADD summary",
	                     colindex:           7.0,
	                     prehook:            :get_summary,
	                     aggregation_method: :add_summary,
	                     type:               :attribute,
	                     checked:            false,
	                     category:           "CADD",
	                     color:              {
		                     /CADD summary.*_phred/ => create_color_gradient([0, 3, 13, 40], colors = ["palegreen", "lightyellow", "salmon", "indianred"]),
		                     /CADD summary.*/ => create_color_gradient([0, 0.5, 1], colors = ["palegreen", "lightyellow", "salmon"])
	                     },
	                     requires:           {
		                     Cadd => [:variation_id]
	                     }


	def aggregate_requirements(rec)
		ret = {}
		self.requirements[Cadd].each do |colname|
			ret[colname] = rec["#{Cadd.aqua_table_alias}.#{colname}"]
		end
		ret
	end
	
	def get_summary(rows, params)
		if params[:experiment].nil? then
			@summary = {}
			return
		end
		organismid = Experiment.find(params[:experiment]).organism_id
		varids     = rows.map {|id, recs| recs.map {|rec| rec["#{Cadd.aqua_table_alias}.variation_id"]}}.flatten.uniq
		@summary   = Cadd.summary(varids, organismid)
	end
	
	def add_summary(rec)
		varid                  = rec["#{Cadd.aqua_table_alias}.variation_id"]
		rec["CADD summary"] = @summary[varid] || {}
	end




end