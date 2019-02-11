class FilterInheritance < SimpleFilter
	create_filter_for QueryInheritance, :inheritance_autosomal_recessive,
	                  name: :autosomal_recessive,
	                  label: "Autosomal Recessive - requires entity relation and parents",
	                  filter_method: lambda{|value, params|
		                  create_condition(
			                  recessive(value, params)
		                  )
	                  },
	                  collection_method: :nil,
	                  organism: [organisms(:human), organisms(:mouse)],
	                  checked: true,
	                  requires: {},
	                  tool: Annotation
	create_filter_for QueryInheritance, :inheritance_autosomal_dominant,
	                  name: :autosomal_dominant,
	                  label: "Autosomal Dominant - requires entity relation and parents",
	                  filter_method: lambda{|value, params|
		                  create_condition(
			                  dominant(value, params)
		                  )
	                  },
	                  collection_method: :nil,
	                  organism: [organisms(:human), organisms(:mouse)],
	                  checked: true,
	                  requires: {},
	                  tool: Annotation
	create_filter_for QueryInheritance, :inheritance_autosomal_dominant,
	                  name: :dominant_only,
	                  label: "Dominant - requires entity relation and parents and one parent to be affected",
	                  filter_method: lambda{|value, params|
		                  create_condition(
			                  dominant(value, params)
		                  )
	                  },
	                  collection_method: :nil,
	                  organism: [organisms(:human), organisms(:mouse)],
	                  checked: false,
	                  requires: {},
	                  tool: Annotation
	create_filter_for QueryInheritance, :inheritance_denovo,
	                  name: :denovo,
	                  label: "denovo - requires entity relation and parents",
	                  filter_method: lambda{|value, params|
		                  create_condition(
			                  denovo(value, params)
		                  )
	                  },
	                  collection_method: :nil,
	                  organism: [organisms(:human), organisms(:mouse)],
	                  checked: true,
	                  requires: {},
	                  tool: Annotation
	create_filter_for QueryInheritance, :inheritance_compound_heterozygous,
	                  name: :compound_heterozygous,
	                  label: "Compound heterozygous - requires entity relation and parents (based on VEP)",
	                  filter_method: lambda{|value, params|
		                  create_condition(
			                  compound_heterozygous(value, params)
		                  )
	                  },
	                  collection_method: :nil,
	                  organism: [organisms(:human), organisms(:mouse)],
	                  checked: true,
	                  requires: {},
	                  tool: Annotation
	
	def autosomal_dominant
		varids = []
		ents = Entity.joins(:samples).where("samples.id" => params[:samples])
		ents.select!{|ent| ent.parents.count == 2}
		ents.each do |ent|
			varids += ent.autosomal_dominant.select{|k,is_arec| is_arec == :Y}.map(&:first)
		end
		varids
	end
	
	def dominant(value, params)
		varids = []
		ents = Entity.joins(:samples).where("samples.id" => params[:samples])
		ents.select!{|ent| ent.parents.count == 2}
		ents.each do |ent|
			varids += ent.autosomal_dominant.select{|k,is_arec| is_arec == :Y || is_arec == :xy}.map(&:first)
		end
		varids
	end
	
	def recessive(value, params)
		varids = []
		ents = Entity.joins(:samples).where("samples.id" => params[:samples])
		ents.select!{|ent| ent.parents.count == 2}
		ents.each do |ent|
			varids += ent.autosomal_recessive.select{|k,is_arec| is_arec == :Y || is_arec == :"?"}.map(&:first)
		end
		varids
	end
	
	def denovo(value, params)
		varids = []
		ents = Entity.joins(:samples).where("samples.id" => params[:samples])
		ents.select!{|ent| ent.parents.count == 2}
		ents.each do |ent|
			varids += ent.denovo.select{|k,is_arec| is_arec == :Y}.map(&:first)
		end
		varids
	end
	
	def compound_heterozygous(value, params)
		varids = []
		if defined?(Vep::Ensembl) then
			ents = Entity.joins(:samples).where("samples.id" => params[:samples])
			ents.select!{|ent| ent.parents.count == 2}
			ents.each do |ent|
				varids += ent.compound_heterozygous.select{|k,is_arec| !is_arec.nil?}.map(&:first)
			end
		else
			return nil
		end
		varids
	end
	
private
	def create_condition(varids)
		return "1 = 0" if (varids || []).size == 0
		"#{ActiveRecord::Base.connection.quote_table_name(VariationCall.table_name)}.#{ActiveRecord::Base.connection.quote_column_name('variation_id')} IN (#{varids.uniq.sort.join(",")})"
	end
	

end