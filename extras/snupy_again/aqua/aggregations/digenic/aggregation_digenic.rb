class AggregationDigenic < Aggregation
	
	@@vepversion  = VepAnnotation.config('ensembl_version')
	@@vepcategory = "VEP v#{@@vepversion}"
	
	register_aggregation :digenic,
						 label:              'Digenic Associations',
						 colname:            'digenic association',
						 colindex:           3.1,
						 prehook:            :prep_digenic,
						 aggregation_method: :digenic_assocs,
						 type:               :attribute,
						 checked:            false,
						 category:           'Digenic Associations',
						 record_color:       {
							 'digenic association[gene]'     => :factor_norm,
							 'digenic association[partners]' => :factor_norm
						 },
						 requires:           {
							 Vep::Ensembl => [:gene_symbol]
						 }
	
	def digenic_assocs(rec)
		gene     = rec[Vep::Ensembl.colname(:gene_symbol)]
		partners = []
		dbs      = ''
		digenics = @digenic[gene]
		if !digenics.nil? then
			partners = digenics.map {|partner, digenic_objs|
				partner
			}
			dbs      = digenics.map {|partner, digenic_objs|
				digenic_objs.map {|d|
					"#{d.source_db}(#{d.association_description}/#{d.disease_name})"
				}.flatten.sort.uniq.join(',')
			}
		else
			gene = nil
		end
		{
			gene:      gene.to_s,
			partners:  partners.join(' | '),
			databases: dbs
		}
	end
	
	def prep_digenic(arr)
		@digenic = {}
		genes    = arr.map {|groupkey, recs|
			recs.map {|rec|
				rec[Vep::Ensembl.colname(:gene_symbol)]
			}
		}.flatten.uniq.map {|x| "'#{x}'"}.join(',')
		
		Digenic.where("gene_id IN (#{genes}) OR gene_partner_id IN (#{genes})").all.each do |digenic|
			@digenic[digenic.gene_id]         ||= {}
			@digenic[digenic.gene_partner_id] ||= {}
			
			@digenic[digenic.gene_id][digenic.gene_partner_id] ||= []
			@digenic[digenic.gene_partner_id][digenic.gene_id] ||= []
			
			@digenic[digenic.gene_id][digenic.gene_partner_id] << digenic
			@digenic[digenic.gene_partner_id][digenic.gene_id] << digenic
		end
	end


end