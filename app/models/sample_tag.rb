# == Description 
# A SampleTag is used to add generic additional Information to samples. We call them tags.
# There is n x m relation between the SampleTag and Samples, which is organized in the sample_has_sample_tag table. 
# == Attributes
# [tag_name] Name
# [tag_value] Tag Value, this is a text in the database, so it can become pretty big.
# [tag_type] This is used to group different tags
class SampleTag < ActiveRecord::Base
	include SnupyAgain::ModelUtils
	
	has_and_belongs_to_many :samples, join_table: :sample_has_sample_tag
  attr_accessible :tag_name, :tag_value, :tag_type, :description

	AVAILABLE_NAMES = %w(TISSUE DISEASE STATUS MALIGNANCY GENDER FAMILYRELATION TOOL DATA_TYPE SAMPLE_GROUP SAMPLE_BACKGROUND)
	AVAILABLE_TYPES = %w(MESH CUSTOM SAMPLE_HIERARCHY ATTRIBUTE SAMPLE_STATUS)
	validates_inclusion_of :tag_name, :in => AVAILABLE_NAMES
	validates_inclusion_of :tag_type, :in => AVAILABLE_TYPES

  before_destroy :destroy_has_and_belongs_to_many_relations

	# == Description
	# When the tag_type is MESH then this validator checks if the formal of tag_value matches /^[[:alnum:], 0-9\-']+ \[[A-Z]([0-9]+\.[0-9]+)+\]$/ 
  class SampleTagValidator < ActiveModel::Validator
	  def validate(record)
	  	if record.tag_type == "MESH" then
	  		# if !(record.tag_value =~ /^[A-Z]([0-9]+\.[0-9]+)+ \- .*$/)
	  		if !(record.tag_value =~ /^[[:alnum:], 0-9\-']+ \[[A-Z]([0-9]+\.[0-9]+)+\]$/)
	  			record.errors[:base] << "'#{record.tag_value}' does not appear to be a valid MESH record. Please follow this pattern 'Carbonyl Cyanide m-Chlorophenyl Hydrazone [D02.442.288.200]' as you can find it in the <a href='http://www.nlm.nih.gov/mesh/MBrowser.html' target='meshbrowser'>MESH term tree browser</a>.".html_safe
	  		end
	  	end
	  end
	end

  validates_with SampleTagValidator
	
	def self.tag_name_category
		ret = {}
		SampleTag.all.each do |st|
			ret[st.tag_name] = [] if ret[st.tag_name].nil?
			ret[st.tag_name] << st
		end 
		ret
	end
	
	def <=> (other)
		if tag_type != other.tag_type
			return tag_type <=> other.tag_type
		end
		if tag_name != other.tag_name
			return tag_name <=> other.tag_name
		end
		if tag_type == "CUSTOM"
			return tag_value <=> other.tag_value
		else
			myval = tag_value.scan(/\[(.*)\]/).flatten.first.to_s.split(".")
			otherval = other.tag_value.scan(/\[(.*)\]/).flatten.first.to_s.split(".")
			if myval.nil? or otherval.nil? then
				myval = tag_value.gsub(/(.*)(\[.*?\])(.*)/, "\\2 \\1 \\3")
				otherval = other.tag_value.gsub(/(.*)(\[.*?\])(.*)/, "\\2 \\1 \\3")
			end
			myval <=> otherval
		end
	end
	
	def destroy_has_and_belongs_to_many_relations
		samples = []
	end
	
	def get_children()
		return [self] if tag_type == "CUSTOM"
		# find ID
		id = tag_value.scan(/\[(.*)\]/).flatten.first
		levels = id.split(".")
		idx = levels.size - 1
		while levels[idx].to_s == "0" do
			levels[idx] = "%"
			idx -= 1
		end
		query_id = levels.join(".")
		SampleTag.where(tag_type: self.tag_type)
						  .where("tag_value LIKE '%[#{query_id}%]%'")
	end
	
end
