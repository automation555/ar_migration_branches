directory = File.dirname( __FILE__ )
require "#{directory}/lib/blank"
require "#{directory}/lib/migration_branches"

#ActiveRecord::Base.send( :include, ActiveRecord::Migrator )
#ActiveRecord::Base.class_eval do
#  include ActiveRecord::Migrator::InstanceMethods
#  extend ActiveRecord::Migrator::SingletonMethods
#end
