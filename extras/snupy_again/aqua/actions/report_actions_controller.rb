class ReportActionsController < AquaController #ApplicationController
	include ApplicationHelper
	include AquaParameterHelper
	
	def gene_report

		# get the entities that are linked to the variaiton calls
		varcallids = (params[:ids] || []).map{|x| x.split(" | ")}.flatten.uniq
		entities = Entity.find(
			Sample.joins(:variation_calls)
				.where("variation_calls.id" => varcallids)
				.pluck(:entity_id).reject(&:nil?).uniq
		)
		entities.select!{|ent| ent.tags.where(category: "CLASS").where("value != 'shared control'").count > 0}
		
		entities.instance_variable_set(:@_table_selected, params[:entity_ids])
		entities.instance_variable_set(:@_table_select_type, :select)
		
		available_templates = ReportEntity.templates

		require_params = {
			ids: params[:ids],
			entities: entities,
			report_template: available_templates
		}.merge(params)
		
		# ask user which entity to report on
		if determine_missing_params(require_params).size > 0 then
			render_table_details_params(require_params, label: "Select a template")
			return true
		else
			# get the template and ask for required parameters
			tklass = ReportTemplate.descendants.select{|k| k.name == params[:report_template]}.first
			require_params = tklass.required_parameters(params)
			if determine_missing_params(require_params).size > 0 then
				render_table_details_params(require_params, label: "Provide more parameters")
				return true
			end
			# For every entity we generate a report
			tklass = ReportTemplate.descendants.select{|k| k.name == params[:report_template]}.first
			success = true
			reports = []
			Entity.where(id: params[:entities]).each do |ent|
			#ent = Entity.where(id: params[:entities]).first
				if tklass && ent then
					tmpl = tklass.new(params.dup.merge({user_id: current_user_id}))
					reports << tmpl.generate_report(ent)
				else
					success = false
				end
			end
			if success then
				render partial: "reports/report_list", locals: {reports: reports}
				return
			else
				render text: "Not a valid template", status: 500
				return
			end
		end
		
		#send_file "tmp/last_Aggregation_sql_1.sql"
		#send_data "test", filename: "someexample.txt", type: "application/text"
		render text: params.pretty_inspect
	end
	
	def acmg_report
		gene_report
	end

end
#if Rails.env == "development"
	Aqua.register_route("report_actions", :gene_report, :post, {type: "variation_id", description: "Create a report."})
	#Aqua.register_route("report_actions", :acmg_report, :post, {type: "variation_id", description: "Create ACMG/AMP variant interpretation report."})
	require_dependency Rails.root.join('extras', 'snupy_again', 'aqua', 'actions', 'report_actions_controller').to_s
#end
