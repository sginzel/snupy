class Organism < ActiveRecord::Base
	attr_accessible :name
#  has_many :variations, through: :variation_annotations, inverse_of: :organisms
#has_many :variation_annotations, inverse_of: :organism
#has_many :genetic_elements, inverse_of: :organism # , through: :variation_annotations
#  has_many :variation_calls, through: :variations, inverse_of: :organism
	has_many :vcf_files, inverse_of: :organism
	has_many :samples, through: :vcf_files
	has_many :variations, through: :samples, inverse_of: :organisms
	has_many :variation_calls, through: :samples, inverse_of: :organism
	has_many :entity_groups
	has_many :entities, through: :entity_groups, class_name: "Entity"
	has_many :specimen_probes, through: :entity_groups

	def self.human
		Organism.where(name: "homo sapiens").first
	end

	def self.homo_sapiens
		self.human
	end

	def self.mouse
		Organism.where(name: "mus musculus").first
	end

	def self.mus_musculus
		self.mouse
	end

	def is_human?
		self.id == Organism.human.id
	end

	def is_mouse?
		self.id == Organism.mouse.id
	end
end
