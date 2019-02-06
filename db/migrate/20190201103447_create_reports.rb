class CreateReports < ActiveRecord::Migration
	def change
		create_table :reports do |t|
			t.string :name, null: false
			t.string :identifier, null: false
			t.integer :xref_id, null: false
			t.string :xref_klass, null: false
			t.string :type
			t.binary :content, limit: (16.megabytes-1), null: false
			t.string :filename
			t.references :user, null: false
			t.references :institution, null: false
			t.string :mime_type, default: "text/plain"
			t.string :description
			
			t.timestamps
		end
		add_index :reports, :user_id
		add_index :reports, :institution_id
		add_index :reports, :xref_id
		add_index :reports, :xref_klass
		
		add_index :reports, :name
		add_index :reports, :identifier
		add_index :reports, :filename
		
		add_index :reports, :mime_type
		add_index :reports, :description
		
		create_table :report_has_variations, :id => false do |t|
			t.references :report
			t.references :variation
		end
		add_index :report_has_variations, [:report_id, :variation_id]
		add_index :report_has_variations, :report_id
	
	end
end
