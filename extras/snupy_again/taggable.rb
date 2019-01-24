module SnupyAgain
	module Taggable
		extend ActiveSupport::Concern
		included do
			
			def self.find_tag_class_name
				klass = self
				while !(klass.superclass.nil? or klass.superclass == ActiveRecord::Base) do
					klass = klass.superclass
				end
				raise "Klass #{self} is not tagable" if klass.superclass.nil?
				klass.name
			end
			
			# Using this will lead to inconsistencies when using .joins on the Object Klass...
			# because only the objects with a tag will be returned.
			has_and_belongs_to_many_with_deferred_save :tags,  
														:class_name => 'Tag',
														:join_table => :tag_has_objects,
														:foreign_key => :object_id,
														:conditions => "tags.object_type = '#{self.find_tag_class_name}'",
														:finder_sql => proc { %{
																SELECT `tags`.* FROM `tags` 
																INNER JOIN `tag_has_objects` ON (`tags`.`id` = `tag_has_objects`.`tag_id` AND `tags`.`object_type` = `tag_has_objects`.`object_type` AND tag_has_objects.object_type = '#{self.class.find_tag_class_name}') 
																WHERE `tag_has_objects`.`object_id` = #{id}
															}.gsub("\t", "")
														}, 
														:counter_sql => proc { %{
																SELECT COUNT(DISTINCT `tags`.id) FROM `tags` 
																INNER JOIN `tag_has_objects` ON (`tags`.`id` = `tag_has_objects`.`tag_id` AND `tags`.`object_type` = `tag_has_objects`.`object_type` AND tag_has_objects.object_type = '#{self.class.find_tag_class_name}') 
																WHERE `tag_has_objects`.`object_id` = #{id}
															}.gsub("\t", "")
														}, 
														:insert_sql => proc { |record| 
															# We need to make sure only valid records are stored - so in case of incosistency we just dont store anything
															if self.class.find_tag_class_name == record.object_type then
																%{INSERT INTO `tag_has_objects` (`object_id`, `tag_id`, `object_type`) VALUES ( #{self.id},#{record.id},"#{self.class.find_tag_class_name}" )}
															else
																"SELECT -1"
															end 
														}
			
			before_destroy :_destroy_tag_relation
			
			def _destroy_tag_relation
				tags = []
			end
			
			def self.available_tags(as_hash = false)
				tags = Tag.where(object_type: self.find_tag_class_name)
				if as_hash
					tmp = {}
					tags.each do |tag|
						tmp[tag.category] = [] if tmp[tag.category].nil?
						tmp[tag.category] << tag
					end
					tags = tmp
					tags.default = []
				end
				tags
			end
			
			def available_tags(as_hash = false)
				self.class.available_tags(as_hash)
			end
			
			def self.available_tags_by_category
				self.available_tags(true)
			end
			
			def available_tags_by_category
				self.class.available_tags(true)
			end
			
			def self.available_categories
				Tag.select("DISTINCT category").where(object_type: self.find_tag_class_name).pluck(:category)
			end
			
			def available_categories
				self.class.available_categories
			end
			
			def tags_by_category
				ret = Hash[available_categories.map{|c| [c,[]]}]
				ret.default = []
				self.tags.each do |tag|
					ret[tag.category] << tag
				end
				ret
			end
			
		end
	end
end