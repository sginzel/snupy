# == Description
# This class represents a generic region in a given coordinate system. So far
# the coordinate system can only be :chromosome to represent chromosomal coordinates.
# == Attributes
# [name] Name of the region (1,2,3,4,5,6,7,8,9.10,11..., 21, X, Y, M)
# [start] start of the region (1-based). See VCF4.1 format documentation for details
# [stop] End of region (not including this position), See VCF4.1 description
# [coord_system] Only :chromsome is allowed so far
class Region < ActiveRecord::Base
	
	include SnupyAgain::ModelUtils
	
  has_many :variations, inverse_of: :region, dependent: :destroy
  has_many :variation_calls, through: :variations
  has_many :samples, through: :variation_calls, inverse_of: :regions
	#has_many :variation_annotations, through: :variations, inverse_of: :region

  
  attr_accessible :name, :start, :stop, :coord_system
  
  validates_inclusion_of :coord_system, :in => [:chromosome]	

	def coord_system
		read_attribute(:coord_system).to_sym
	end

	def coord_system= (value)
		write_attribute(:coord_system, value.to_s)
	end

	def overlaps?(other_region)
		return false if other_region.name != self.name
		#return false if other_region.stop <= self.start
		#return false if other_region.start >= self.stop
		return (self.range.cover?(other_region.start) or self.range.cover?(other_region.stop)) 
	end
	
	def range
		self.start.to_i..self.stop.to_i
	end
	
	def <=> (other_region)
		return nil if other_region.coord_system != self.coord_system 
		if other_region.name != self.name
			## use numeric sort if both names are numbers
			if self.name =~ /^[0-9]+$/ and other_region.name =~ /^[0-9]+$/ then
				return self.name.to_i <=> other_region.name.to_i
			else
				return self.name <=> other_region.name
			end 
		else
			if other_region.start != self.start
				return self.start <=> other_region.start
			else
				return self.stop <=> other_region.stop
			end
		end
	end

	# merges overlapping regions
	# if include merges is given we return an ordered Hash that 
	# contains the merged regions as keys and the partial regions
	# as values
	def self.deflate(regions, include_merges = false)
		newregs = self.deflate!(regions.dup)
		if include_merges then
			ret = {}
			newregs.each do |mergedreg|
				ret[mergedreg] = regions.select{|r| mergedreg.overlaps?(r)}
			end
		else
			ret = newregs
		end
		ret
	end

	def self.deflate!(regions)
		regions.sort!
		if regions.size > 1 then
			i = 0
			while i < regions.length - 1 do
				if regions[i].overlaps?(regions[i+1]) then
					regions[i] = Region.merge(regions[i], regions[i+1])
					regions.delete_at(i+1)
				else
					i = i + 1
				end
			end
		end
		regions
	end

	def self.merge(region1, region2)
		return nil if region1.coord_system != region2.coord_system
		return nil if region1.name != region2.name
		if region1.overlaps?(region2) then
			newreg = {
				name: region1.name,
				coord_system: region1.coord_system,
				start: [region1.start, region2.start].min,
				stop: [region1.stop, region2.stop].max,
			}
			return Region.new(newreg)
		else
			return nil
		end
	end
	
	def self.overlapping_variations(ids, smpls = [])
		conditions = []
		if smpls.size == 0 then
			regions = Region.where("id" => ids)
		else
			regions = Region.joins(:variation_calls).where("variation_calls.sample_id IN (?)", smpls)
		end
		
		regions.each do |r|
			conditions << Region.where("(name = ? AND ((start >= ? AND stop < ?) OR (? BETWEEN start AND stop) OR (? BETWEEN start AND stop)) AND coord_system = ?)", r.name, r.start, r.stop, r.start, r.stop, r.coord_system).arel.where_sql
			conditions[-1] = conditions[-1].gsub(/^WHERE/, "")
		end
		scope = Variation.joins(:region).where(conditions.join(" OR "))
		return(scope)
	end
	
	def overlapping_variations
		return Region.overlapping_variations(self.id)
	end
	
end
