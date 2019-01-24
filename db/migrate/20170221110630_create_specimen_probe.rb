class CreateSpecimenProbe < ActiveRecord::Migration
	def change
		create_table :specimen_probes do |t|
			t.references :entity
			t.string :name
			t.text :notes
			t.integer :date_day, default: nil
			t.integer :date_month, default: nil
			t.integer :date_year, default: nil
			t.string :lab, default: nil
			t.string :lab_contact, default: nil
			t.string :internal_identifier, default: nil
			t.float :tumor_content, default: nil
			t.string :tumor_content_notes, default: nil
			t.integer :days_after_treatment, default: nil
			t.boolean :queryable, default: false

			t.timestamps
		end
		
		add_index :specimen_probes, :entity_id
		add_index :specimen_probes, :name
		add_index :specimen_probes, [:entity_id, :name], unique: true
		add_index :specimen_probes, :date_day
		add_index :specimen_probes, :date_month
		add_index :specimen_probes, :date_year
		add_index :specimen_probes, :lab
		add_index :specimen_probes, :lab_contact
		add_index :specimen_probes, :internal_identifier
		add_index :specimen_probes, :tumor_content
		add_index :specimen_probes, :tumor_content_notes
		add_index :specimen_probes, :days_after_treatment
		add_index :specimen_probes, :queryable
		
		add_column :samples, :specimen_probe_id, :integer, default: nil
		add_index :samples, :specimen_probe_id
		
		# TODO remove this
		#create_table :specimen_probe_has_vcf_files do |t|
		#	t.references :specimen_probe
		#	t.references :vcf_file
		#end
		
		#add_index :specimen_probe_has_vcf_files, :specimen_probe_id
		#add_index :specimen_probe_has_vcf_files, :vcf_file_id
		#add_index :specimen_probe_has_vcf_files, [:specimen_probe_id, :vcf_file_id], name: "specimen_probe_vcf_index", unique: true
		
	end
end
