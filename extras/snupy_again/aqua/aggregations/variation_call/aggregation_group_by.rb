class AggregationGroupBy < Aggregation
	
	register_aggregation :group_by_variation,
												label: "Variation",
												colname: "Variation",
												colindex: 0,
												aggregation_method: :group_by_variation,
												type: :group,
												checked: true,
												category: "Variation",
												requires: {
													VariationCall => [:variation_id]
												}
	
	register_aggregation :group_by_overlap,
												label: "Overlap regions",
												colname: "Overlap regions",
												colindex: 0,
												prehook: :preprocess_overlap_group,
												aggregation_method: :group_by_overlap,
												type: :group,
												checked: false,
												category: "Variation",
												requires: {
#													VariationCall => [:variation_id],
													Variation => {
														Region => [:id, :name, :start, :stop]
													}
												}
	
	def group_by_variation(rec)
		rec["variation_calls.variation_id"]
	end
	
	def group_by_overlap1(rec)
		rec["overlap_group"]
	end
	
	# this group filter is able to find overlaps and assign each variation_call.id a unique identifier
	# during pre processing each range is assigned its variation_calls - which can be multiple
	# All ranges are distinguished by chromosome
	# no mering is done here
	def preprocess_overlap_group(recs)
		@chr2range2vc = {} if @chr2range2vc.nil?
		recs.each do |rec|
			chr = rec["regions.name"]
			range = ((rec["regions.start"].to_i)..(rec["regions.stop"].to_i))
			@chr2range2vc[chr] = {} if @chr2range2vc[chr].nil?
			@chr2range2vc[chr][range] = [] if @chr2range2vc[chr][range].nil?
			@chr2range2vc[chr][range] << rec["variation_calls.id"]
		end
		
	end
	
	# when we need to assign a record_key to a record we first check if the reverse lookup exists
	# if it doesnt we perform the merge operation on the first call only
	def group_by_overlap(rec)
		if @vc2range.nil? then
			merge_overlaps()
		end
		vcid = rec["variation_calls.id"]
		@vc2range[vcid]
	end
	
	def merge_overlaps
		@vc2range = {}
		@chr2range2vc.each do |chr, range2vc|
			# sort the ranges
			ranges = range2vc.keys.sort{|r1, r2|
				if r1.begin != r2.begin then
					r1.begin <=> r2.begin
				else
					r2.end <=> r2.end
				end
			}
			# perform merging
			idx = 0
			while (idx < ranges.size-1)
				# puts "CHR#{chr}/#{idx}:#{ranges.join(", ")}"
				# check if the current range overlaps with the next one
				r1 = ranges[idx]
				r2 = ranges[idx+1]
				if (r1.overlaps?(r2)) then
					newr = [r1.begin, r2.begin].min..[r1.end, r2.end].max
					vc1 = range2vc.delete(r1)
					vc2 = range2vc.delete(r2)
					range2vc[newr] = vc1 + vc2
					ranges[idx] = newr
					ranges.delete_at(idx+1)
				else
					idx += 1
				end
			end
			# set reverse lookup
			range2vc.each do |range, vcids|
				key = vcids.uniq.sort.join(" | ")
				vcids.uniq.each do |vcid|
					# @vc2range[vcid] = "#{chr}_#{range.begin}_#{range.end}"
					@vc2range[vcid] = key
				end
			end
		end
	end
	
end