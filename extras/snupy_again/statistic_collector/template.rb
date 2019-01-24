module SnupyAgain
	module StatisticCollector
		class Template

			@@APPLICABLE_TO = {}
			
			## this method keeps track of which classes are applicable to which models
			def self.attr_collectable(*args)
				@@APPLICABLE_TO[self] = [] if @@APPLICABLE_TO[self].nil?
				args.each do |m|
					@@APPLICABLE_TO[self] << m.downcase.to_s unless @@APPLICABLE_TO[self].include?(m.downcase.to_s)
				end
				true
			end
			
			def self.applicable_to(model)
				if !model.is_a?(String)
					if model.is_a?(Class) then
						model = model.name
					else
						model = model.class.name
					end
				end
				return @@APPLICABLE_TO[self].include?(model.downcase.to_s)
			end

			def self.collectors(model = nil)
				## loading the directory is required for the objects to be initialized
				classes = SnupyAgain::Utils.load_directory("extras/snupy_again/statistic_collector/**/**")
				return SnupyAgain::StatisticCollector::Template.descendants if model.nil? 
				SnupyAgain::StatisticCollector::Template.descendants.select{|c| c.applicable_to(model)}
			end
			
			def self.batchrefresh(model, ids, force = false)
				@objects = model.find(ids)
				@objects.each do |object|
					collector = self.new(object)
					collector.collect(force)
				end
				true
			end
			
			def initialize(object)
				raise "New Operation is not applicable to this parameter" unless self.applicable_to(object)
				@object = object
			end
			
			def applicable_to(model)
				self.class.applicable_to(model) 
			end
			
			def self.auto_calculate()
				return true
			end
			
			def auto_calculate()
				self.class.auto_calculate
			end
			
			def collect(force = false)
				existing_stat = @object.statistics.where(resource: self.class.name).first
				if !force then
					return existing_stat unless existing_stat.nil?
				else
					existing_stat.delete unless existing_stat.nil?
				end
				stat = do_collect()
				if !stat.persisted?
					stat.resource = self.class.name
					stat.save!
				end
				stat
			end

			def do_collect(model)
				raise NotImplementedError.new("not implemented")
			end
			
		end
	end
end