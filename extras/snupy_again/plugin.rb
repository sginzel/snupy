module SnupyAgain
	module Plugin
		include SnupyAgain::Utils
		## define calss methods to be overwritten/added
		module ClassMethods
			def repository
				@_repository ||= []
			end
			
			def refresh_repository
				@_repository = self.descendants
			end
			
			def inherited(klass)
				repository << klass
			end
		end
		# when the module is included add the class methods defined above
		def self.included(klass)
			klass.extend ClassMethods# Somewhat controversial
		end
	end
end