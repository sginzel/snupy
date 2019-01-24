class EntityGroup < ActiveRecord::Base

	include SnupyAgain::Taggable
	
	has_and_belongs_to_many :experiments, join_table: :experiment_has_entity_groups
	
	# has_and_belongs_to_many :institutions, join_table: :institution_has_entity_groups
	belongs_to :institution
	has_and_belongs_to_many :users, join_table: :user_has_entity_groups
	
	belongs_to :organism
	
	has_many :entities, dependent: :destroy #, class_name: "Entity"
	has_many :specimen_probes, through: :entities
	has_many :variation_calls, through: :entities
	has_many :samples, through: :specimen_probes
	has_many :vcf_files, through: :samples,
			 select: [:id, :contact, :filename, :md5checksum, :sample_names, :status, :institution_id, :name, :organism_id, :type, :filters, :updated_at, :created_at].map{|attr| "vcf_files.#{attr}"}
	
	has_many :vcf_file_nodata, through: :samples,
							class_name: "VcfFile", 
							foreign_key: "vcf_file_id",
							readonly: true,
							select: 
								[:id, :contact, :filename, :md5checksum, :sample_names, :status, :institution_id, :name, :organism_id, :type, :filters].map{|attr| "vcf_files.#{attr}"}
	
	## tags
	has_and_belongs_to_many :entity_group_tags, class_name: "Tag", join_table: :tag_has_objects, foreign_key: :object_id,
							:conditions => { "tags.object_type" => "EntityGroup"}
	has_many :entity_tags, class_name: "Tag", through: :entities, :uniq => true
	has_many :specimen_probe_tags, class_name: "Tag", through: :specimen_probes, :uniq => true
	has_many :sample_tags, class_name: "Tag", through: :samples, :uniq => true
	has_many :vcf_file_tags, class_name: "Tag", through: :vcf_files, :uniq => true
	
	attr_accessible :name, :institution_id, :organism_id, :complete, :contact
	
	before_destroy :destroy_has_and_belongs_to_many_relations

	validates :name, presence: true, allow_blank: false, uniqueness: true
	validates :institution_id, presence: true, allow_blank: false
	validates :organism_id, presence: true, allow_blank: false


	class EntityGroupValidator < ActiveModel::Validator
		def validate(record)
			begin
				raise "Name can't be emtpy" if record.name.to_s == ""
				if record.samples.size > 0 then
					sample_insts = record.samples.includes(:institution).map{|s| s.institution.id}.uniq
					sample_orgs = record.samples.includes(:organism).map{|s| s.organism.id}.uniq
					if sample_insts.size > 1 then
						record.errors[:base] << "Samples of #{record.name} belong to different institutions. this is not allowed."
					end
					if sample_insts.first != record.institution_id then
						record.errors[:base] << "Samples do not belong to the same institution as the entity group. This is not allowed."
					end
					if sample_orgs.size > 1 then
						record.errors[:base] << "Samples of #{record.name} belong to different organisms. this is not allowed."
					end
					if sample_orgs.first != record.organism_id then
						record.errors[:base] << "Samples do not belong to the same organism as the entity group. This is not allowed."
					end
				end
			rescue StandardError => e
				record.errors[:base] << "Could not save Entity (#{e.message})"
			end
		end
	end
	validates_with EntityGroupValidator

	def destroy_has_and_belongs_to_many_relations
		experiments = []
		users = []
		institutions = []
		entities.update_all(entity_group_id: nil)
	end

	def to_s
		"[EntityGroup-#{name.to_s}]"
	end

	def dataset_summary(give_reason = true)
		EntityGroup.dataset_summary([self.id], give_reason)
	end
	
	def self.dataset_summary(ids, give_reason = true)
		@validations = {
				entity: {},
				specimen: {}
		}
		# dataset_summary = EntityGroup.where(id: ids).includes([:entities => [:tags], :specimen_probes => [:tags], :samples => [:tags], :vcf_file_nodata => [:tags]]).map{|eg|
		dataset_summary = EntityGroup.where(id: ids).includes([:entities, :specimen_probes, :samples, :vcf_file_nodata, :institution]).map{|eg|
			ret = []
			ret << dataset_summary_record(give_reason, eg) if eg.entities.size == 0
			eg.entities.each do |ent|
				ret << dataset_summary_record(give_reason, eg, ent) if ent.specimen_probes.size == 0
				ent.specimen_probes.each do |specimen|
					ret << dataset_summary_record(give_reason, eg, ent, specimen) if specimen.samples.size == 0
					specimen.samples.each do |sample|
						ret << dataset_summary_record(give_reason, eg, ent, specimen, sample, sample.vcf_file_nodata)
					end
				end
			end
			ret
		}.flatten
		return dataset_summary
	end
	
	def self.upload_template
		{
			institution: "#{Institution.pluck(:name).join(",")}",
			organism: "#{Organism.pluck(:name).join(",")}",
			entity_group: "EntityGroupName",
			entity: "EntityName",
			entity_tags: "Tag1|Tag2",
			specimen_probe: "SpecimenName",
			specimen_probe_tags: "Tag3|Tag4",
			sample: "SampleName",
			entity_internal_identifier: "",
			specimen_probe_internal_identifier: "",
			specimen_probe_lab: "",
			specimen_probe_lab_contact: ""
		}
	end
	
	def self.create_from_upload(filepath_or_records, user)
		# fin = File.new(filepath, 'r')
		dofail = false
		results = []
		if filepath_or_records.is_a?String then
			records = []
			begin
				CSV.foreach(filepath_or_records, col_sep: "\t", headers: true, quote_char: '"') do |row|
					records << row.to_hash
				end
			rescue CSV::MalformedCSVError => e
				raise
			end
		elsif filepath_or_records.is_a?(Hash) then
			records = filepath_or_records.values
		else
			records = filepath_or_records
		end
		## filter records that are empty, especially relevant when not submitted as a file
		records.reject!{|rec|
			rec['institution'].to_s == '' ||
			rec['organism'].to_s == '' ||
			rec['entity_group'].to_s == ''
		}
		EntityGroup.transaction do
			# CSV.foreach(filepath, col_sep: "\t", headers: true, quote_char: '"') do |row|
			records.each do |row|
				begin
					row.keys.each{|k|
						row[k] = row[k].strip unless row[k].nil?
					} # make sure no white spaces get in the way
					result            = parse_upload_record(row, user)
					result['Message'] = 'OK'
				rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid => e
					dofail            = true
					result            = row
					result.keys.each{|k| result[k.to_sym] = result.delete(k)} # make sure the keys are symbols
					result['Message'] = "[ERROR]" + e.message
				end
				results << result
			end
			if dofail then
				results.each{|rec| rec['ERROR']='Nothing was added to the database, because of errors.' unless rec['ERROR']}
				raise ActiveRecord::Rollback
			end
		end
		results
	end
	
	
	
private
	
	def self.parse_upload_record(row, user)
		tag_sep = '|'
		notes = []
		entity_group_created = ''
		entity_created = ''
		specimen_probe_created = ''

		if row['institution'].to_s != '' then
			institution = Institution.where(name: row['institution']).first
			raise ActiveRecord::RecordNotFound.new("Institution '#{row['institution']}' not found") if institution.nil?
			if not user.institutions.include?(institution)
				raise ActiveRecord::RecordNotFound.new("User #{user.name} is not part of '#{row['institution']}'") if institution.nil?
			end
		else
			institution = Institution.new
		end
		
		if row['organism'].to_s != '' then
			organism = Organism.where(name: row['organism']).first
			raise ActiveRecord::RecordNotFound.new("Institution '#{row['organism']}' not found") if organism.nil?
		else
			organism = Organism.new
		end
		
		## Entity Group
		if row['entity_group'].to_s != '' then
			eg = EntityGroup.find_or_initialize_by_name_and_institution_id_and_organism_id(row['entity_group'], institution.id, organism.id)
			raise ActiveRecord::RecordNotFound.new("Cant create Entity Group '#{row['entity_group']}' reason: #{eg.errors[:base]}") if eg.nil?
			if not eg.persisted? then
				eg.users << user
				eg.contact = "Batch created by #{user.name}"
				eg.save!
				entity_group_created = "(NEW ##{eg.id})"
			else
				if user.editable(EntityGroup).where('entity_groups.id' => eg.id).size == 0
					raise ActiveRecord::RecordNotFound.new("User #{user.name} cant modify Entity Group '#{row['entity_group']}'")
				else
					notes << "EntityGroup #{eg.name} exists for institution #{institution.name}. Not created."
				end
			end
		else
			eg = EntityGroup.new
		end
		
		## Entity
		if (row['entity'].to_s != '') then
			ent = Entity.find_or_initialize_by_name_and_entity_group_id(row['entity'], eg.id)
			raise ActiveRecord::RecordNotFound.new("Cant create Entity '#{row['entity']}' reason: #{ent.errors[:base]}") if ent.nil?
			if not ent.persisted? then
				ent_tags_given = row['entity_tags'].to_s.split(tag_sep).map(&:strip)
				ent_tags = Tag.where(object_type: 'Entity', value: ent_tags_given)
				raise ActiveRecord::RecordNotFound.new("EntityTags '#{row['entity_tags'].to_s}' not found") if ent_tags.size != ent_tags_given.size or ent_tags_given.size == 0
				ent.tags = ent_tags
				ent.contact = user.name
				ent.notes = "Batch created by #{user.name}"
				ent.internal_identifier = row['entity_internal_identifier']
				ent.save!
				entity_created = "(NEW ##{ent.id})"
			else
				notes << "Entity #{ent.name} exists for EntityGroup #{eg.name}. Not created. No tags assigned."
				ent_tags = ent.tags
			end
		else
			ent = Entity.new
			ent_tags = []
		end
		
		## SpecimenProbe
		if (row['specimen_probe'].to_s != '') then
			sp = SpecimenProbe.find_or_initialize_by_name_and_entity_id(row['specimen_probe'], ent.id)
			raise ActiveRecord::RecordNotFound.new("Cant create Specimen '#{row['specimen_probe']}' reason: #{sp.errors[:base]}") if sp.nil?
			# only add tags and specimen if it didnt exist before
			if not sp.persisted? then
				sp_tags_given = row['specimen_probe_tags'].to_s.split(tag_sep).map(&:strip)
				sp_tags = Tag.where(object_type: 'SpecimenProbe', value: sp_tags_given)
				raise ActiveRecord::RecordNotFound.new("SpecimenTags '#{row['specimen_probe_tags'].to_s}' not found") if sp_tags.size != sp_tags_given.size or sp_tags_given.size == 0
				sp.tags = sp_tags
				sp.notes = "Batch created by #{user.name}"
				sp.lab = row['specimen_probe_lab']
				sp.lab_contact = row['specimen_probe_lab_contact']
				sp.internal_identifier = row['specimen_probe_internal_identifier']
				sp.save!
				specimen_probe_created = "(NEW ##{sp.id})"
			else
				notes << "Specimen #{sp.name} exists for Entity #{ent.name}. Not created. No tags assigned."
				sp_tags = sp.tags
			end
		else
			sp = SpecimenProbe.new
			sp_tags = []
		end
		
		## Sample
		if (row['sample'].to_s != '') then
			smpl = Sample.where(name: row['sample']).first
			raise ActiveRecord::RecordNotFound.new("Sample '#{row['sample']}' does not exist and cant be created. reason: #{(!smpl.nil?)?smpl.errors[:base]:''}") if smpl.nil?
			# only add tags and specimen if it didnt exist before
			if smpl.specimen_probe_id.nil? then
				if user.editable(Sample).where('samples.id' => smpl.id).size == 0
					raise ActiveRecord::RecordNotFound.new("User #{user.name} cant modify Sample '#{row['sample']}'")
				else
					smpl.specimen_probe_id = sp.id
					smpl.save!
				end
			else
				notes << "Sample #{smpl.name} exists and is already assigned to a specimen (#{smpl.specimen_probe_id}). Nothing was done."
			end
		else
			smpl = Sample.new
		end
		
		{
			id:                  eg.id,
			institution:         "#{institution.name}",
			organism:            "#{organism.name}",
			entity_group:        ["#{eg.name}", "#{entity_group_created}"],
			entity:              ["#{ent.name}", "#{entity_created}"],
			entity_tags:         ent_tags.map{|t| "#{t.category}: #{t.value}"},
			specimen_probe:      ["#{sp.name}", "#{specimen_probe_created}"],
			specimen_probe_tags: sp_tags.map{|t| "#{t.category}: #{t.value}"},
			sample:              "#{smpl.name}",
			note:                notes.join(','),
			entity_internal_identifier: ent.internal_identifier,
			specimen_probe_internal_identifier: sp.internal_identifier,
			specimen_probe_lab: sp.lab,
			specimen_probe_lab_contact: sp.lab_contact
		}
	end
	
	def self.dataset_summary_record(give_reason = true, eg = nil, ent = nil, specimen = nil, sample = nil, vcf_file = nil)
		@validations = {} unless defined?@validations
		inst_name = ""
		eg_name = ""
		ent_name = ""
		specimen_name = ""
		sample_name = ""
		vcf_name = ""
		spec_queryable = ""
		
		institution = nil
		institution = eg.institution unless eg.nil? or eg.institution.nil?
		
		inst_name = eg.institution.name unless eg.nil? or eg.institution.nil?
		eg_name = eg.name unless eg.nil?
		ent_name = ent.name unless ent.nil?
		specimen_name = specimen.name unless specimen.nil?
		sample_name = sample.name unless sample.nil?
		vcf_name = vcf_file.name unless vcf_file.nil?
		spec_queryable = specimen.queryable unless specimen.nil?
		
		annot_missing = []
		if give_reason then
			if !spec_queryable then
				annot_missing << "Reasons: "
				unless ent.nil? then
					if @validations[:entity][ent.id].nil? then
						ent_validation = Entity::EntityTagValidator.new(ent).validate(ent)
						ent_validation = nil if ent_validation == []
						@validations[:entity][ent.id] = ""
						@validations[:entity][ent.id] = "Entity(#{ent.name}): #{ent_validation.join(',')}" unless ent_validation.nil?
					end
					annot_missing << @validations[:entity][ent.id]
				end
				unless specimen.nil? then
					if @validations[:specimen][specimen.id].nil? then
						spec_validation = SpecimenProbe::SpecimenProbeTagValidator.new(specimen).validate(specimen)
						spec_validation = nil if spec_validation == []
						@validations[:specimen][specimen.id] = ""
						if spec_validation == false then
							@validations[:specimen][specimen.id] = "Specimen(#{specimen.name}): Reason unknown" unless spec_validation.nil?
						else
							@validations[:specimen][specimen.id] = "Specimen(#{specimen.name}): #{spec_validation.join(',')}" unless spec_validation.nil?
						end
					end
					annot_missing << @validations[:specimen][specimen.id]
				end
			end
		end
		annot_missing = annot_missing.join("<br>")
		
		eg_show = ""
		eg_edit = ""
		
		inst_name = create_link(inst_name, eg.institution, :institution_path) unless eg.nil? or eg.institution.nil?
		eg_name = create_link(eg_name, eg, :entity_group_path) unless eg.nil?
		ent_name = create_link(ent_name, ent, :entity_path) unless ent.nil?
		specimen_name = create_link(specimen_name, specimen, :specimen_probe_path) unless specimen.nil?
		sample_name = create_link(sample_name, sample, :sample_path) unless sample.nil?
		vcf_name = create_link(vcf_name, vcf_file, :vcf_file_path) unless vcf_file.nil?
		
		# inst_name = ActionController::Base.helpers.link_to(inst_name, Rails.application.routes.url_helpers.institution_path(eg.institution.id)) unless eg.nil? or eg.institution.nil?
		#eg_name = ActionController::Base.helpers.link_to(eg_name, Rails.application.routes.url_helpers.entity_group_path(eg), {data: {context: {show: eg_show, edit: eg_edit}}}) unless eg.nil?
		#ent_name = ActionController::Base.helpers.link_to(ent_name, Rails.application.routes.url_helpers.entity_path(ent)) unless ent.nil?
		#specimen_name = ActionController::Base.helpers.link_to(specimen_name, Rails.application.routes.url_helpers.specimen_probe_path(specimen)) unless specimen.nil?
		#sample_name = ActionController::Base.helpers.link_to(sample_name, Rails.application.routes.url_helpers.sample_path(sample)) unless sample.nil?
		#vcf_name = ActionController::Base.helpers.link_to(vcf_name, Rails.application.routes.url_helpers.vcf_file_path(vcf_file)) unless vcf_file.nil?
		
		if ent.nil? and !eg.nil? then
			ent_name << " | " + ActionController::Base.helpers.link_to("NEW", Rails.application.routes.url_helpers.new_entity_path(entity_group_id: eg.id, institution_id: eg.institution_id)) unless eg.nil?
		end
		
		if specimen.nil? and !ent.nil? then
			specimen_name  << " | " + ActionController::Base.helpers.link_to("NEW", Rails.application.routes.url_helpers.new_specimen_probe_path(entity_id: ent.id, entity_group_id: eg.id, institution_id: eg.institution_id)) unless eg.nil?
		end
		
		if !specimen.nil? and sample.nil? then
			sample_name  << " | " + ActionController::Base.helpers.link_to("LINK", Rails.application.routes.url_helpers.specimen_probes_path(ids: specimen.id)) unless specimen.nil?
		end
		
		{
			"Institution" => inst_name,
			"Entity Group" => eg_name,
			"Entity" => ent_name,
			"Specimen" => specimen_name,
			"Sample" => sample_name,
			"VcfFile" => vcf_name,
			"Queryable?" => spec_queryable,
			"Reason" => annot_missing,
			"_raw" => {
				institution: (institution || Institution.new).id,
				egroup: (eg || EntityGroup.new).id,
				entity: (ent || Entity.new).id,
				specimen: (specimen || SpecimenProbe.new).id,
				specimen_probe: (specimen || SpecimenProbe.new).id,
				sample: (sample || Sample.new).id,
				vcf_file: (vcf_file || VcfFile.new).id
			}
		}
		
		# specimen_name = "#{specimen.name}[#{(specimen.tags_by_category["STATUS"] || []).map(&:value).join(",")}]"
		# sample_name = "#{sample.name}[#{(sample.tags_by_category["DATA_TYPE"] || []).map(&:value).join(",")}]"
		#{
		#	"Entity Group" => ActionController::Base.helpers.link_to(eg.name, Rails.application.routes.url_helpers.entity_group_path(eg)),
		#	"Entity" => ActionController::Base.helpers.link_to(ent.name, Rails.application.routes.url_helpers.entity_path(ent)),
		#	"Specimen" => ActionController::Base.helpers.link_to(specimen_name, Rails.application.routes.url_helpers.specimen_probe_path(specimen)),
		#	"Sample" => ActionController::Base.helpers.link_to(sample_name, Rails.application.routes.url_helpers.sample_path(sample)),
		#	"Queryable?" => spec_queryable
		#}
	end

private 
	def self.create_link(text, obj, path, opts = {})
		#data: {context: {show: eg_show, edit: eg_edit}}
		if opts.size == 0 then
			opts[:data] = {context:{}}
			edit_path = "edit_#{obj.class.name.underscore}_path".to_sym
			show_path = "#{obj.class.name.underscore}_path".to_sym
			index_path = "#{obj.class.name.underscore.pluralize}_path".to_sym
			if (Rails.application.routes.url_helpers.respond_to?(edit_path)) then
				opts[:data][:context][:edit] = Rails.application.routes.url_helpers.send(edit_path, obj)
			end
			if (Rails.application.routes.url_helpers.respond_to?(show_path)) then
				opts[:data][:context][:show] = Rails.application.routes.url_helpers.send(show_path, obj)
			end
			if obj.is_a?(EntityGroup) or obj.is_a?(Entity) or obj.is_a?(SpecimenProbe) or obj.is_a?(Sample) then
				if (Rails.application.routes.url_helpers.respond_to?(index_path)) then
					opts[:data][:context][:reassign] = Rails.application.routes.url_helpers.send(index_path, {ids: obj.id})
				end
			end
		end
		ActionController::Base.helpers.link_to(text, Rails.application.routes.url_helpers.send(path, obj), opts) 
	end

end
