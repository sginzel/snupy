module TagsHelper
	def assign_tags
		mdl = Kernel.const_get(self.class.name.gsub("Controller", "").singularize.to_sym)

		if params[:ids].nil? or params[:ids].size != 1 then
			render text: "Please select one Entity Group."
			return false
		end

		categories = mdl.available_tags_by_category.keys
		require_params = {
				ids: params[:ids],
				category: categories
		}

		if determine_missing_params(require_params).size > 0 then
			render_table_details_params(require_params, label: "Select a category")
			return true
		else
			tags = mdl.available_tags_by_category[params[:category]]
			if params[:ids].size == 1 then
				objs = mdl.find(params[:ids]).first
				tags.instance_variable_set(:@_table_selected, objs.tag_ids)
				tags.instance_variable_set(:@_table_select_type, :select)
			end

			require_params = {
					ids: params[:ids],
					category: params[:category],
					tags: tags
			}
			if params[:tags_length].nil? and determine_missing_params(require_params).size > 0 then
				render_table_details_params(require_params, label: "Select a tag to apply")
				return true
			else
				objs = mdl.find(params[:ids])
				tags = Tag.find((params[:tags] || []))
				if params[:ids].size == 1 then
					obj = objs.first
					curr_tags = obj.tags_by_category
					curr_tags[params[:category].to_s] = tags
					obj.tags = curr_tags.values.flatten
					success = obj.save
					if success then
						render text: "[Success] modified tags for #{mdl.name}##{params[:ids].first}"
					else
						render text: "[Error] tags for #{mdl.name}##{params[:ids].first}. #{obj.errors.messages.pretty_inspect}", status: 500
					end
				else
					tags.each do |t|
						t.push_objects(objs)
					end
					render text: "[Success] added #{tags.size} to #{objs.size} #{mdl.name}"
				end
				return true
			end
		end
	end
end
