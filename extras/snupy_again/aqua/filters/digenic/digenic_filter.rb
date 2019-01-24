class DigenicFilter < ComplexFilter
	create_filter_for QueryDigenic, :digenic,
					  name: :digenic,
					  label: "Digenic Filtering",
					  filter_method: :digenic_filter,
					  collection_method: :find_digenic_databases,
					  organism: [organisms(:human), organisms(:mouse)],
					  checked: false,
					  requires: {
						  Vep::Ensembl => [:gene_symbol],
						  Sample => [:id, :specimen_probe_id]
					  },
					  tool: VepAnnotation

	# return a new array
	def digenic_filter(arr, values)

		# load digenic associations
		diassoc = {}
		Digenic.where(source_db: values.map{|value| value.gsub(/^'/, '').gsub(/'$/, '')}).select([:gene_id, :gene_partner_id]).each do |digenic|
			g1, g2 = [digenic.gene_id, digenic.gene_partner_id]
			diassoc[g1] ||= Hash.new(false)
			diassoc[g2] ||= Hash.new(false)
			diassoc[g1][g2] = true
			diassoc[g2][g1] = true
		end
		return [] if diassoc.size == 0
		# load a matrix that contains all specimen <-> gene associtions from the query
		# if specimen is not avaialable we can fall back to the sample_id
		# Vep::Ensembl.colname(:gene_symbol)
		spec2gene = {}
		smpl2gene = {}
		arr.each do |rec|
			spec2gene[rec['samples.specimen_probe_id']] ||= Hash.new(false)
			smpl2gene[rec['samples.id']] ||= Hash.new(false)
			spec2gene[rec['samples.specimen_probe_id']][rec[Vep::Ensembl.colname(:gene_symbol)]] = true
			smpl2gene[rec['samples.id']][rec[Vep::Ensembl.colname(:gene_symbol)]] = true
		end
		arr.select{|rec|
			#only keep records where the sample_id or specimen_id have another hit in the partner
			keep = false
			gene = rec[Vep::Ensembl.colname(:gene_symbol)]
			gene_assocs = diassoc[gene]
			if !gene_assocs.nil?
				if rec['samples.specimen_probe_id'].nil? then
					othrhits = smpl2gene[rec['samples.id']]
				else
					othrhits = spec2gene[rec['samples.specimen_probe_id']]
				end
				keep = gene_assocs.keys.any?{|partner| othrhits[partner] }
			end
			keep
		}
	end
	
	def find_digenic_databases(params)
		ret = Digenic.select(:source_db).uniq.pluck(:source_db).sort.map{|c|
			{
				id: c,
				database: c
			}
		}
		ret
	end
	

end