class Tag < ActiveRecord::Base
	
	attr_accessible :category, :object_type, :subcategory, :value, :description
	
	validates_inclusion_of :object_type, :in => [Sample, VcfFile, SpecimenProbe, Entity, EntityGroup, Variation, VariationCall].map(&:name)
	validates :category, presence: true, allow_blank: false
	validates :value, presence: true, allow_blank: false
	validates_uniqueness_of :object_type, scope: [:category, :value]

	before_destroy :remove_links
	
	def to_s(compact = true)
		if compact
			[category, subcategory, value].reject{|x| x.to_s == ""}.join("_")
		else
			[object_type, category, subcategory, value].reject{|x| x.to_s == ""}.join("_")
		end

		#"##{object_type}_#{category}_#{subcategory}_#{value}"
	end
	
	def object_klass
		Kernel.const_get(self.object_type)
	end
	
	def remove_links
		link_with([], true)
	end
	
	def objects(return_vcf_content = false)
		return object_klass.where("1 = 0") if self.object_type.nil? # return empty when the object is initialized
		return object_klass.where("1 = 0") if self.id.nil?
		klass = object_klass
		
		if return_vcf_content || object_type != VcfFile.find_tag_class_name then
			klass.joins(%{
				INNER JOIN `tag_has_objects` ON (`tag_has_objects`.`tag_id` = #{id} AND `tag_has_objects`.`object_type` = '#{object_type}' AND `tag_has_objects`.`object_id` = #{klass.table_name}.#{klass.primary_key})
			})
		else
			klass.joins(%{
				INNER JOIN `tag_has_objects` ON (`tag_has_objects`.`tag_id` = #{id} AND `tag_has_objects`.`object_type` = '#{object_type}' AND `tag_has_objects`.`object_id` = #{klass.table_name}.#{klass.primary_key})
			}).nodata
		end
	end

	def objects=(new_objects)
		link_with(new_objects, true)
	end

	def object_ids()
		objects.pluck(:"#{object_klass.table_name}.#{object_klass.primary_key}")
	end
	
	def push_objects(new_objects)
		link_with(self.objects.all + [new_objects], true)
	end

	def available_objects(return_vcf_content = false)
		return [] if self.object_type.nil? # return empty when the object is initialized
		return [] if self.object_type.to_s == ""
		klass = Kernel.const_get(self.object_type)
		if return_vcf_content || object_type != VcfFile.find_tag_class_name
			klass.scoped
		else
			klass.nodata
		end
	end
	
	#' this method takes a batch of ids and creates links between the objects and the tags
	#' this is neccessary because we don't know the objects we are being linked to
	#' thus we can't create has_and_belong_to_many relations to them 
	def link_with(ids, i_know_what_i_am_doing = false)
		raise "you dont know what you are doing" unless i_know_what_i_am_doing
		# verify that all objects exist
		return false if ids.nil?
		ids = [ids] unless ids.is_a?(Array)
		ids = ids.flatten.map{|obj|
			if obj.is_a?(ActiveRecord::Base) then
				obj.id
			else
				obj.to_i
			end
		}.uniq.sort
		if ids.size > 0 then
			klass = Kernel.const_get(self.object_type)
			objids = klass.where(id: ids).pluck(:id).sort
			if objids.size != ids.size then
				raise RecordNotFound("Not all objects exist.")
			end
		end
		
		existing = ActiveRecord::Base.connection.execute("SELECT object_id FROM tag_has_objects WHERE object_type = '#{object_type}' AND tag_id = #{id}").to_a.flatten
		ids_to_keep = ids & existing
		ids_to_delete = existing - ids_to_keep
		ids_to_add = ids - existing
		Tag.transaction do
			if ids_to_delete.size > 0 then
				ActiveRecord::Base.connection.execute("DELETE FROM tag_has_objects WHERE tag_id = #{id} AND object_id IN (#{ids_to_delete.join(",")})")
			end
			
			if ids_to_add.size > 0 then
				statement = ids_to_add.map{|id_to_link|
					"(#{id}, '#{object_type}', #{id_to_link})"
				}
				ActiveRecord::Base.connection.execute("INSERT INTO tag_has_objects (tag_id, object_type, object_id) VALUES #{statement.join(",")}")
			end
		end
		
	end
	
	def variation_ids
		find_relation_to_parallel(Variation, "variations.id")
	end
	
	def variation_call_ids
		find_relation_to_parallel(VariationCall, "variation_calls.id")
	end
	
	def variations
		Variation.where(id: self.variation_ids)
	end
	
	def variation_calls
		Variation.where(id: self.variation_call_ids)
	end
	
	def samples
		find_relation_to(Sample).uniq
	end
	
	def specimen_probes
		find_relation_to(SpecimenProbe).uniq
	end
	
	def entities
		find_relation_to(Entity).uniq
	end
	
	def entity_groups
		find_relation_to(EntityGroup)
	end
	
	
	private
	
	def find_relation_to(klass)
		if klass.name == self.object_type then
			return self.objects
		end
		ret = find_relation_to_sequential(klass)
		if ret.nil? then
			ret = klass.where("1 = 0")
		end
		ret
	end
	
	def find_relation_to_parallel(klass, column = "id")
		if klass.name == self.object_type then
			return self.objects
		end
		assoc = Aqua.find_association(klass, self.object_klass)
		myobjects = self.object_ids.each_slice(10).to_a
		result = []
		Parallel.each(myobjects, in_threads: 4) do |objids|
			ActiveRecord::Base.connection_pool.with_connection do
				result << klass.joins(assoc.name).where("#{object_klass.table_name}.#{object_klass.primary_key}" => objids).pluck(column)#.order("#{klass.table_name}.#{klass.primary_key}")
			end
		end
		result.flatten
	end
	
	def find_relation_to_sequential(klass)
		# find relation between object and variation
		assoc = Aqua.find_association(klass, self.object_klass)
		return nil if assoc.nil?
		#klass.where(id:
			klass.joins(assoc.name).where("#{object_klass.table_name}.#{object_klass.primary_key}" => self.object_ids)#.order("#{klass.table_name}.#{klass.primary_key}")
			#klass.joins(assoc.name).where("#{object_klass.table_name}.#{object_klass.primary_key}" => self.object_ids).order("#{object_klass.table_name}.#{object_klass.primary_key}")
		#)
	end
	
end
