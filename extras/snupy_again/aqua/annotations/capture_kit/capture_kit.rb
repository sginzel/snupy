class CaptureKit < ActiveRecord::Base
	@@CAPTUREKITCONFIG = YAML.load_file(File.join(Rails.root, "extras", "snupy_again", "aqua", "annotations" ,"capture_kit", "capture_kit.yaml"))[Rails.env]
	@@CAPTUREKITTABLENAME = "capture_kit#{@@CAPTUREKITCONFIG["version"].to_s.gsub(".", "_")}s".to_sym # there is a pending s to be confirm with RAILS pluralized table form
	self.table_name = @@CAPTUREKITTABLENAME

	# optional, but handy associations
	belongs_to :variation
	belongs_to :organism
	has_one :alteration, through: :variation
	has_one :region, through: :variation
	has_many :variation_calls, foreign_key: :variation_id, primary_key: :variation_id
	has_many :samples, through: :variation_calls
	has_many :users, through: :samples
	has_many :experiments, through: :samples

	has_one :capture_kit_file

	# list all attributes here to mass-assign them
	attr_accessible :variation_id,
									:organism_id,
									:dist,
									:capture_kit_file_id
	
	# optional method in case you want to do inheritance
	def self.aqua_table_alias
		self.table_name
	end
	
end

