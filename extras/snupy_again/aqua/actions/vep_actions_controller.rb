# The Aqua Controller is not in the autoload path
# if you change anything here you need to restart the serveur
class VepActionsController < AquaController #ApplicationController
	include ApplicationHelper
	include AquaParameterHelper

	def test_vep
		ids = params[:ids].map{|id| id.split(" | ")}.flatten
		render text: "#{ids.join(",")}"
	end

	# The burden test maps all mutations to their genes, it then select all available mutations for that gene
	# and check how often the gene is hit by at least so many mutations in the samples
	def burden_test
		varids = params[:ids].map{|id| id.split(" | ")}.flatten

		render text: "#{ids.join(",")}"
	end

	# This test checks how many control and how many case samples have a higher BAF than the ones observed
	def baf_test
		varids = params[:ids].map{|id| id.split(" | ")}.flatten
		ids = ((params[:ids] || params[:variation_call_id])|| params[:variation_call_ids])
		smplids = params["samples"]
		if ids.is_a?(Array) then
			ids = ids.map{|id| id.split(" | ")}.flatten
		end
		ids = [ids] if !ids.nil? and !ids.is_a?(Array)
		variation_ids = (params[:variation_ids] || params[:variation_id])
		if variation_ids.is_a?(Array) then
			variation_ids = variation_ids.map{|id| id.split(" | ")}.flatten
		end
		variation_ids = [variation_ids] if !variation_ids.nil? and !variation_ids.is_a?(Array)

		#if ((ids || []).size > 5000) then
		#	render text: "Not more than 5000 variations allowed"
		#	return true
		#end

		@details = []
		@variation_ids = []
		@variation_ids += VariationCall.where(id: ids).pluck(:variation_id).uniq unless ids.nil?
		@variation_ids += variation_ids unless variation_ids.nil?


		if (!params[:experiment_id].nil?) then
			@experiment = Experiment.find(params[:experiment_id])
		else
			@experiment = Experiment.new
		end

		@samples = (current_user.reviewable(Sample) + current_user.visible(Sample) + @experiment.samples).uniq
		# prepare entity lookup
		@entity2tags = {}
		@entities = (current_user.reviewable(Entity) + current_user.visible(Entity) + @experiment.entities).uniq
		@entities = Entity.joins(:tags).includes(:tags).where("entities.id" => @entities)
		@entities.uniq.each do |ent|
			@entity2tags[ent.id.to_i] = {
					is_control: ent.tags.any?{|t| t.value == "shared control"}
			}
		end
		@entity2tags[nil] = {is_control: nil}

		details = {}
		selected_ents = []
		Aqua.scope_to_array(
				Variation.where(id: @variation_ids).joins([:alteration, :region]).includes([:region, :alteration]), true
		){|rec|
			details[rec['variations.id']] = {} if details[rec['variations.id']].nil?
			details[rec['variations.id']]['chr'] = rec['regions.name']
			details[rec['variations.id']]['from'] = rec['regions.start']
			details[rec['variations.id']]['to'] = rec['regions.stop']
			details[rec['variations.id']]['ref'] = rec['alterations.ref']
			details[rec['variations.id']]['alt'] = rec['alterations.alt']
			details[rec['variations.id']]['id'] = []
			details[rec['variations.id']]['samples'] = []
			details[rec['variations.id']]['specimen_probes'] = []
			details[rec['variations.id']]['entities'] = []
			details[rec['variations.id']]['entity_groups'] = []
			details[rec['variations.id']]['bafs'] = []
			details[rec['variations.id']]['num.missing_association'] = 0
			details[rec['variations.id']]['num.case'] = 0
			details[rec['variations.id']]['num.control'] = 0
			details[rec['variations.id']]['variation_id'] = rec['variations.id']
		}
		# add number of case/controls and statistics
		Aqua.scope_to_array(
				VariationCall.joins(:sample).where(sample_id: @samples).where(variation_id: @variation_ids)
						.select([
												"variation_calls.variation_id AS variation_id",
												"variation_calls.id AS variation_call_id",
												"samples.id AS sample_id",
												"samples.specimen_probe_id AS specimen_probe_id",
												"samples.entity_id AS entity_id",
												"samples.entity_group_id AS entity_group_id",
												"(variation_calls.alt_reads/(variation_calls.ref_reads+variation_calls.alt_reads)) AS baf"
										])
		){|rec|
			details[rec['variation_id']] = {} if details[rec['variation_id']].nil?
			# initilization of more fields
			if (details[rec['variation_id']]['id'].nil?)

			end
			details[rec['variation_id']]['id'] << rec['variation_call_id']
			details[rec['variation_id']]['samples'] << rec['sample_id']
			details[rec['variation_id']]['specimen_probes'] << rec['specimen_probe_id']
			details[rec['variation_id']]['entities'] << rec['entity_id']
			details[rec['variation_id']]['entity_groups'] << rec['entity_group_id']
			details[rec['variation_id']]['bafs'] << rec['baf']
			selected_ents << rec['entity_id'] if smplids.include?(rec['sample_id'].to_s)
		}

		fstest = Rubystats::FishersExactTest.new
		details.keys.each do |varid|
			## count how often the baf is higher than in the current sample
			details[varid]['higher'] = 0
			details[varid]['lower'] = 0
			details[varid]['case'] = 0
			details[varid]['control'] = 0
			record = details[varid]
			# find max baf per entity
			maxbaf = {}
			iscontrol = {}
			iscase = {}
			record['entities'].each_with_index{|entity, idx|
				next if entity.nil?
				maxbaf[entity] ||= 0.0
				maxbaf[entity] = [maxbaf[entity], record['bafs'][idx]].max.to_f
				iscontrol[entity] = maxbaf[entity] if (@entity2tags[entity] || {})[:is_control]
				iscase[entity] = maxbaf[entity] unless (@entity2tags[entity] || {})[:is_control]
			}
			selected_ents.uniq!
			selected_ents.each do |entity|
				next if entity.nil?
				mybaf = maxbaf[entity]
				case_higher_baf = 0
				case_lower_baf = 0
				control_higher_baf = 0
				control_lower_baf = 0
				(record['entities'].uniq - selected_ents).each do |entiter|
					next if entiter.nil? # no association to control or case
					case_higher_baf += iscase.select{|ent, baf| baf > mybaf && ent != entiter}.size
					case_lower_baf += iscase.select{|ent,  baf| baf < mybaf && ent != entiter}.size
					control_higher_baf += iscontrol.select{|ent, baf| baf > mybaf && ent != entiter}.size
					control_lower_baf += iscontrol.select{|ent, baf| baf < mybaf && ent != entiter}.size
				end
				pvals = fstest.calculate(case_higher_baf, case_lower_baf, control_higher_baf, control_lower_baf)
				@details << {
						id: varid,
						entity: entity,
						chr: record['chr'],
						start: record['start'],
						stop: record['stop'],
						ref: record['ref'],
						alt: record['alt'],
						case_higher_baf: case_higher_baf,
						case_lower_baf: case_lower_baf,
						control_higher_baf: control_higher_baf,
						control_lower_baf: control_lower_baf,
						pval_greater: pvals[:right],
						pval_lesser: pvals[:left],
						pval_twotail: pvals[:twotail],
						variation_id: varid
				}
			end

		end

		aqua_actions = {}
		experiment = @experiment
		Aqua.route_paths.each do |description, url|
			aqua_actions[description] = {url: url, params: {experiment_id: experiment.id, samples: smplids, queries: params["queries"], aggregations: params["aggregations"]}}
		end
		aqua_actions = aqua_actions.merge(
				{
						"Look-up variations in other samples" => {url: details_experiments_path(experiment: experiment.id),    params: {samples: smplids, tags: 'yes', queries: params["queries"], aggregations: params["aggregations"]}},
						"Show interactions" => {url: interactions_experiments_path(experiment: experiment.id),                 params: {samples: smplids, queries: params["queries"], aggregations: params["aggregations"]}},
						"Attribute matrix" => {url: attribute_matrix_experiments_path(experiment: experiment.id),              params: {samples: smplids, queries: params["queries"], aggregations: params["aggregations"]}},
						"Gene panel to subject" => {url: panel_to_subject_matrix_experiments_path(experiment: experiment.id),  params: {samples: smplids, queries: params["queries"], aggregations: params["aggregations"]}},
						"Save selected records" => {url: save_resultset_experiments_path(experiment: experiment.id),          params: {samples: params[:samples], queries: params["queries"], aggregations: params["aggregations"]}}
				}
		)
		render_table(@details,
								 title:  "BAF tests for selected variants",
								 id:     "baf_test_#{Time.now.to_i}",
								 colors: {
										 "pval_greater" => create_color_gradient([0, 0.05, 1], ["salmon", "lightyellow", "palegreen"]),
										 "pval_lesser" => create_color_gradient([0, 0.05, 1], ["salmon", "lightyellow", "palegreen"]),
										 "pval_twotail" => create_color_gradient([0, 0.05, 1], ["salmon", "lightyellow", "palegreen"])
								 },
								 actions: aqua_actions
		)
	end

end

#Aqua.register_route("vep_actions", :test_vep, :post, {type: "variation_id", description: "Some Test"})
# Aqua.register_route("vep_actions", :burden_test, :post, {type: "variation_id", description: "Some Test"})
#Aqua.register_route("vep_actions", :baf_test, :post, {type: "variation_id", description: "Baf Test"})
