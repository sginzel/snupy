require 'test_helper'

class DataAccessTest < ActionDispatch::IntegrationTest
	setup do
		@experiment = experiments(:experiment)
		@entity_group = entity_groups(:trio)
		@entity = entities(:child1)
		@specimen_probe = specimen_probes(:trio_child)
		@sample = samples(:sample_child1)
		@vcf_file = vcf_files(:vcf_file_gatk)
		@user = users(:normal_user)
		@institution = institutions(:ukd)

		rest = [:new, :create, :edit, :update, :show, :destroy, :index]
		show = [:index, :show]
		create = [:new, :create]
		edit = [:edit, :update]
		destroy = [:destroy]
		aqua = [:aqua, :aqua_meta, :details, :interactions, :interaction_details]

		entity_group_actions = [:show_dataset_summary, :assign_entity]
		entity_actions = [:assign_specimen_probe, :assign_entity_group]
		specimen_probe_actions = [:assign_sample, :assign_entity]
		sample_actions = [:sample_similarity, :gender_coefficient, :assign_specimen]
		sample_manage_actions = [:collectstats, :mass_destroy, :force_reload, :claimable, :refreshstats]
		vcf_file_actions = [:assign_tags, :download]
		vcf_file_manage_actions = [:aqua_annotate, :create_sample_sheet, :download_sample_sheet, :batch_submit]

		all = rest +
				aqua +
				entity_group_actions +
				entity_actions +
				specimen_probe_actions +
				sample_actions +
				sample_manage_actions +
				vcf_file_actions +
				vcf_file_manage_actions

		@access_rules = {
				normal_user: {
						can: {
								@experiment => rest + aqua,
								@entity_group => create + show + edit + entity_group_actions,
								@entity => create + show + edit + entity_actions,
								@specimen_probe => create + show + edit + specimen_probe_actions,
								@sample => show + edit + sample_actions,
								@vcf_file => [:index],
								@user => show,
								@institution => show
						},
						cannot: {
								@experiment => [],
								@entity_group => destroy,
								@entity => destroy,
								@specimen_probe => destroy,
								@sample => create + destroy + sample_manage_actions,
								@vcf_file => create + destroy + vcf_file_actions + [:show] + vcf_file_manage_actions,
								@user => create + edit + destroy,
								@institution => create + edit + destroy
						}
				},
				data_manager: {
						can: {
								@experiment => rest + aqua,
								@entity_group => rest + entity_group_actions,
								@entity => rest + entity_actions,
								@specimen_probe => rest + specimen_probe_actions,
								@sample => rest + sample_actions + sample_manage_actions,
								@vcf_file => rest + vcf_file_actions + vcf_file_manage_actions,
								@user => show,
								@institution => show
						},
						cannot: {
								@experiment => [],
								@entity_group => [],
								@entity => [],
								@specimen_probe => [],
								@sample => [],
								@vcf_file => [],
								@user => create + edit + destroy,
								@institution => create + edit + destroy
						}
				},
				research_manager: {
						can: {
								@experiment => show + aqua,
								@entity_group => show + entity_group_actions,
								@entity => show + entity_actions,
								@specimen_probe => show + specimen_probe_actions,
								@sample => show + sample_actions,
								@vcf_file => show + [:download],
								@user => show,
								@institution => show
						},
						cannot: {
								@experiment => [],
								@entity_group => [],
								@entity => [],
								@specimen_probe => [],
								@sample => [] + sample_manage_actions,
								@vcf_file => [] + [:assign_tags] + vcf_file_manage_actions,
								@user => create + edit + destroy,
								@institution => create + edit + destroy
						}
				},
				admin: {
						can: {
								@experiment => rest + aqua,
								@entity_group => rest + entity_group_actions,
								@entity => rest + entity_actions,
								@specimen_probe => rest + specimen_probe_actions,
								@sample => rest + sample_actions + sample_manage_actions,
								@vcf_file => rest + vcf_file_actions + vcf_file_manage_actions,
								@user => rest,
								@institution => rest
						},
						cannot: {
								@experiment => [],
								@entity_group => [],
								@entity => [],
								@specimen_probe => [],
								@sample => [],
								@vcf_file => [],
								@user => [],
								@institution => []
						}
				},
				foreign_user: {
						can: {
								@experiment => create + [:index],
								@entity_group => create + [:index] + [:show_dataset_summary],
								@entity => create + [:index],
								@specimen_probe => create + [:index],
								@sample => [:index] + (sample_actions - [:assign_specimen]),
								@vcf_file => [:index],
								@user => show,
								@institution => show
						},
						cannot: {
								@experiment => edit + destroy + [:show] + aqua,
								@entity_group => edit + destroy + [:show] + (entity_group_actions - [:show_dataset_summary]),
								@entity => edit + destroy + [:show] + entity_actions,
								@specimen_probe => edit + destroy + [:show] + specimen_probe_actions,
								@sample => create + edit + destroy + [:show] + sample_manage_actions,
								@vcf_file => create + edit + destroy + [:show] + vcf_file_actions + vcf_file_manage_actions,
								@user => create + edit + destroy,
								@institution => create + edit + destroy
						}
				}
		}
	end

	test 'Access rules' do
		@access_rules.each do |user, rules|
			(rules[:can] || {}).each do |obj, actions|
				actions.each do |action|
					assert_ability(user, action, obj, "#{user} can not #{action} #{obj.class.name}")
				end
			end
			(rules[:cannot] || {}).each do |obj, actions|
				actions.each do |action|
					assert_inability(user, action, obj, "#{user} can #{action} #{obj.class.name}")
				end
			end
		end
	end


end
