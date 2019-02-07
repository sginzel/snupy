class ReportActionsController < AquaController #ApplicationController
	include ApplicationHelper
	include AquaParameterHelper
	
	def gene_report
		# get the entities that are linked to the variaiton calls
		varcallids = params[:ids].map{|x| x.split(" | ")}.flatten.uniq
		entities = Entity.find(
			Sample.joins(:variation_calls)
				.where("variation_calls.id" => varcallids)
				.pluck(:entity_id).reject(&:nil?).uniq
		)
		entities.instance_variable_set(:@_table_selected, params[:entity_ids])
		entities.instance_variable_set(:@_table_select_type, :radio)
		
		available_templates = ReportEntity.templates
		
		
		require_params = {
			ids: params[:ids],
			entities: entities,
			gene_panels: current_user.visible(GenericGeneList),
			report_template: available_templates
		}
		
		# ask user which entity to report on
		if determine_missing_params(require_params).size > 0 then
			render_table_details_params(require_params, label: "Select a template")
			return true
		else
			# For every entity we generate a report
			tklass = ReportTemplate.descendants.select{|k| k.name == params[:report_template]}.first
			ent = Entity.where(id: params[:entities]).first
			if tklass && ent then
				tmpl = tklass.new
				txt = tmpl.generate_report(ent,
				                           {
					                           variation_call_ids: varcallids,
					                           panels: params[:gene_panels]
				                           },
				                           {description: "Gene Report for #{ent.name} (#{Date.today})"})
				# render text: txt.to_yaml + "<br>" + params.pretty_inspect
				# ActionController::Base.helpers.link_to("#{rec['variation_calls.gt']} (#{rec['samples.nickname']})", Rails.application.routes.url_helpers.samples_path(ids: [rec['variation_calls.sample_id']]))
				render html: "#{ActionController::Base.helpers.link_to 'XXX', Rails.application.routes.url_helpers.download_report_path(txt.id||3)}".html_safe
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
	
end
Aqua.register_route("report_actions", :gene_report, :post, {type: "variation_id", description: "Generate a report for selected variants."})