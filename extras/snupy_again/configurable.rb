# == Description
# This module enables to easily make classes configurable by a developer. 
module SnupyAgain
	module Configurable
		
		@@CONFIGURATIONS = {}
		@@DEFAULT = {}
		
		# This method can be used if the developer wants to use another verb instead of configure
		def set_confname(confname)
			self.define_singleton_method(confname.to_s.to_sym) do |section, opts|
				configure(section, opts)
			end
			self.define_singleton_method("load_#{confname.to_s}".to_sym) do |section, opts|
				load_configuration(section, opts)
			end
			self.define_singleton_method(confname.to_s.pluralize.to_sym) do 
				configurations()
			end
		end
		
		# load a configuration of a section. The opts parameter enables defaults
		def load_configuration(section, opts = {})
			myconf = configurations(section)
			raise "section '#{section}' does not exist" if myconf.nil?
			myconf.merge(opts)
		end
		
		# Returns all configurations. If sections is not nil return the configuration of section
		def configurations(section = nil)
			return (@@CONFIGURATIONS[self] || (@@CONFIGURATIONS[self] = {})) if section.nil?
			(@@CONFIGURATIONS[self] || (@@CONFIGURATIONS[self] = {}))[section]
		end
		
		# return the section default
		def section_default()
			(@@DEFAULT[self] || (@@DEFAULT[self] = {}))
		end
		
		# Set section default
		def set_section_default(default)
			raise ArgumentError.new("Default has to be a hash") unless default.is_a?(Hash)
			@@DEFAULT[self] = default
		end
		
		# Used to write the configuration of a sections using opts.
		def configure(section, opts)
			raise "section must not be nil" if section.nil?
			d "[WARNING] Class#{self} is already configured." unless self.configurations(section).nil?
			default_opts = self.section_default()
			opts = default_opts.merge(opts)
			self.configurations[section] = {_conf_section: section}.merge(opts)
		end
		
		# returns a list of sections
		def sections()
			(@@CONFIGURATIONS[self] || {} ).keys
		end
		
	end
end