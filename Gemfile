source 'https://rubygems.org'

gem 'rails', '3.2.22.5'

# Bundle edge Rails instead:
# gem 'rails', :git => 'git://github.com/rails/rails.git'

# gem 'sqlite3', "1.3.7" # incompatible with ruby 2.4 and rails 3.2.22.5
gem 'sqlite3', "1.3.13"

gem "nokogiri", "1.6.0"

# Gems used only for assets and not required
# in production environments by default.
group :assets do
	gem "sass", "3.2.5"
	#gem 'sass-rails', '3.2.3' # upgrade ruby 2.3
	gem 'sass-rails', '3.2.6'
	#gem 'coffee-rails', '3.2.1' # ruby 2.4 upgrade
	gem 'coffee-rails', '3.2.2'
	
	# See https://github.com/sstephenson/execjs#readme for more supported runtimes
	# gem 'therubyracer', "0.11.3", :platforms => :ruby # updates for ruby 2.4
	gem 'therubyracer', "0.12.3", :platforms => :ruby # updates for ruby 2.4
	
	gem 'uglifier', '>= 1.0.3'
	
	# gem 'jquery-datatables-rails', '~> 1.11.2', git: 'https://github.com/rweng/jquery-datatables-rails.git'
	# gem 'jquery-datatables-rails', '~> 3.4.0', git: 'https://github.com/rweng/jquery-datatables-rails.git'
	# gem 'jquery-datatables-rails', '3.4.0', git: 'https://github.com/rweng/jquery-datatables-rails.git', tag: "v3.4.0" # now loaded from data.tables website in application layout header.
	# gem 'jquery-ui-rails', '~> 4.1.0', git: 'https://github.com/joliss/jquery-ui-rails.git'
	
	# changed Nov. 2017
	# gem 'jquery-ui-rails', '4.1.0', git: 'https://github.com/joliss/jquery-ui-rails.git', tag: "v4.1.0"
	# gem 'jquery-ui-sass-rails'
	gem 'jquery-ui-rails', '5.0.1'#, git: 'https://github.com/jquery-ui-rails/jquery-ui-rails.git', tag: "v5.0.1"
	

end

group :development do
	# gem 'thin'
	gem 'unicorn'
	gem "rails-erd"
	
	# gem install ruby-debug19 -- --with-ruby-include=$rvm_path/src/ruby-1.9.2-p290
	# rvmsudo gem install debugger -- --with-ruby-include=$rvm_path/src/ruby-1.9.3-head
	gem "debugger-ruby_core_source"
	# gem 'debugger' # not supported on rails 3.2.22.5 and ruby 2.4
	
	# gem "linecache19", :git => 'git://github.com/mark-moseley/linecache'
	# gem "linecache19", :git => 'https://github.com/mark-moseley/linecache.git'
	
	
	#gem "ruby-debug-base19"
	#gem "ruby-debug-ide19"
	#gem "ruby-debug19"
	
	gem "ruby-prof", "0.16.2"
	
	## remove by SGINZE2S - to check for errors in console output related to logging.
	# memory usage analyse
	#	gem "hodel_3000_compliant_logger"
	#	gem "oink"
	
	#notify you when you should add eager loading (N+1 queries), when you're using eager loading that isn't necessary and when you should use counter cache.
	#	gem "ruby_gntp"
	#	gem "uniform_notifier"
	#	gem "bullet"
	## for debug purpors
	gem 'wirble', "0.1.3"
	gem 'test-unit', '~> 3.0'
end
gem 'interactive_editor', "0.0.10"

# changed Nov. 2017
# gem 'jquery-rails', "2.2.1"
gem 'jquery-rails', '3.1.3', git: 'https://github.com/rails/jquery-rails.git', tag: "v3.1.3"

# gem 'activerecord-mysql-adapter'
gem 'mysql2', '~> 0.3.21'
# gem 'mysql2', '~> 0.4.6' # does not work with Rails 3.2, only with 4.2 - checkout compability section https://libraries.io/github/brianmario/mysql2

# gem 'activerecord-mysql2-adapter'

# this gem enables us to use validation on HABTM relations, as used in experiment
# in the experiment model we have to check if the selected samples are from the same
# organism. Usually the relation between the samples and the experiment is set up
# after the experiment was saved, thus not enabling us to cancel the save-process
# if the selected samples dont belongt to the same organism
gem 'deferred_associations', "0.5.5"

# To use ActiveModel has_secure_password
# gem 'bcrypt-ruby', '~> 3.0.0'

# To use Jbuilder templates for JSON
# gem 'jbuilder'

# Use unicorn as the app server
# gem 'unicorn'

# Deploy with Capistrano
# gem 'capistrano'

# To use debugger
# gem 'debugger'

## this requires a seperate process to be started
## but it can be started in production mode via RAILS_ENV=production scripts/delayed_job start
## with two processes
## RAILS_ENV=production script/delayed_job -n 2 start
## in development
## rake jobs:work 
gem 'daemons', "1.1.9"
# gem 'delayed_job_active_record', "0.4.1"
gem 'delayed_job_active_record', "4.1.2" # upgrade 2017

## annotation
gem 'vcf', "0.0.5", :git => "https://github.com/sginzel/vcfruby.git"

## store files
# gem 'paperclip'

## debug helper
gem 'log_buddy', "0.6.0"


# gem 'spreadsheet', "1.1.0" # for use with statsample 2.0
gem 'spreadsheet', "0.6.5.9"

gem 'turnout', "0.2.5"

gem "flot-rails", "0.0.4"

gem "d3-rails", "3.3.6"

## install ruby-gsl package in ubuntu first
## also follow the instruction on the website
## I had to also install the libblas package in ubuntu 12.10
## SCI Ruby is not compatible with the latest version of GSL, you have to manually install GSL 1.14, follow these instructions:
## http://stackoverflow.com/questions/10316140/i-have-an-error-when-i-install-gsl-with-netbeans
## This also requires gem 1.8.6 to be installed or you will receive a "searcher not found" exception
## Get it through rvm rubygems --force 1.8.6
##
## when you also want to use R on the same maschine you have to update the alternatives to liblapack after you installed the 
## ATLAS libraries so NMatrix can be built against those libraries
## Example: http://www.stat.cmu.edu/~nmv/2013/07/09/for-faster-r-use-openblas-instead-better-than-atlas-trivial-to-switch-to-on-ubuntu/
gem "sciruby", "0.2.11" #"0.1.3"

# gem "rubyvis", "0.6.1" #"0.6.0"

gem "statsample", "1.4.3"
# gem "statsample", "2.0.2" # this breaks active record. 

gem "rubystats", "0.2.5" # "0.2.3"

## setup nmatrix on ubuntu
## sudo apt-get install libatlas-base-dev
## export CPLUS_INCLUDE_PATH=/usr/include/atlas
## export C_INCLUDE_PATH=/usr/include/atlas

## sudo update-alternatives --config liblapack.so
## sudo update-alternatives --config liblapack.so.3

### from http://www.macadie.net/2012/07/31/installing-nmatrix-from-sciruby/
## sudo ln -s /usr/lib/atlas-base/libcblas.so /usr/lib/libcblas.so
## sudo ln -s /usr/lib/atlas-base/libatlas.so /usr/lib/libatlas.so

## sudo ldconfig

## Install the GEM
## rvmsudo gem install nmatrix -- --with-lapacklib
## or using rails you have to first execute bundle config to pass parameters to the build process
## bundle config build.nmatrix --with-lapacklib
# #
#  We came this far... but nmatrix depends on Rdoc 4.0.1 which resolves in a conflict with 
#  rails-jquery-ui gem, that needs 3.4... according to this thread:
#  https://github.com/SciRuby/nmatrix/issues/149 
#  the problem will be resolved soon...
# gem "nmatrix", ">=0.0.9"


## Enable color Gradients
gem "color", "1.7.1"
gem "interpolate", "0.3.0"

## Enables ZIP file support
gem "zip", "2.0.2"

## OJ JSON parser
# gem "oj", '2.15.0' # incompatible with rails 3.2.22.5 and ruby 2.4
gem "oj", '3.3.9'

## enable role and permissions for users
# gem 'access-granted', '~> 1.1.0'
gem 'cancancan', '1.12.0'
# gem 'assignable_values'
gem 'enumerize', "1.1.1"

gem 'package', '0.0.1'

gem 'fast_trie', '0.5.1'

gem 'parallel', '1.12.0'

gem 'bio-bgzf', '0.2.1'

# for nice data.frame like methods - not used yet
# gem 'daru'

# EU Cookies
gem 'cookies_eu', '1.7.1'

gem 'colorize', '0.8.1'

gem 'rbtree', '0.4.2'

gem 'net-ssh', '5.0.2'
gem 'net-ssh-gateway', '2.0.0'

# This gem would provide a nice way to rank attributes based on their significance in the database
# The way this is implemented is not so nice
gem 'quantile', '0.2.1'
#
# This estimator is not very exact it seems
# gem 'numo-gsl', '0.1.2'