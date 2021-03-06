directory = File.dirname( __FILE__ )
require "active_record"
require "#{directory}/../init.rb"

module Rake
  module TaskManager
    def remove_task( task_name )
      @tasks.delete( task_name.to_s )
    end
  end
end

namespace :db do
  Rake::application.remove_task( "db:migrate" ) # Remove the Rails migration task from Rake Tasks.

  desc "Migrate the database through scripts in db/migrate. \n\tTarget a specific version with VERSION=x from the command line."
  task :migrate => :environment do
    branches = ( ENV["branches"] || ENV["BRANCHES"] || ENV["Branches"] ).to_s.strip.gsub( /\s/, "_" ).split( ',' )

    if branches.include?( "all" )
      all_branches =  ( `cd #{Dir.pwd}/db/migrate;ls -d */` ).gsub( /\/$/, '' ).split( "\n" )
      branches = all_branches.insert( 0, nil )
    elsif ( branches.nil? || branches.empty? )
      branches = [nil]
    end
    
    # Check if the working direcory has 'db/' directory
    unless ( `cd #{Dir.pwd}; ls -d */ | grep db` ).strip == "db/"
      raise StandardError.new("\nrake db:migrate must be run from the RAILS_ROOT directory!")
    end

    # Specify the default branch if branches are empty
    unless branches.find { | x | x.to_s.match( /default:.*/ ) }.nil?
      branches.delete( "default" ) and branches.insert( 0, nil ) 
    end

    branches.uniq! # This should be changed to delete duplicate branches or error out on duplicate
    # Example: branch_1:3,branch_1:4
    branch_versions = { }
    branches.each do | branch_string |
      branch_name, target_version = ( branch_string.nil? ? [ nil, nil ] : branch_string.to_s.split( ':' ) )
      branch_name = nil if branch_name == "default"
      target_version = ENV["VERSION"] if ( branch_name.nil? && target_version.nil? && !ENV["VERSION"].nil? && ENV["VERSION"].to_i > 0 )

      ActiveRecord::Migrator.branch = branch_name
      puts "branch: #{branch_name}"
      #ActiveRecord::Migrator.target_version = target_version
      #ActiveRecord::Migrator.initialize_branch_schema
      
      branch_versions[branch_name] = { :start => ActiveRecord::Migrator.current_version, :end => nil }
      
      puts "Migrating db/migrate/#{branch_name}#{ " to version #{target_version}" unless target_version.nil?}"
      migrations_path = "db/migrate/#{branch_name + '/' unless branch_name.to_s.empty?}"
      version = target_version.to_i > 0 ? target_version.to_i : nil
      
      ActiveRecord::Migrator.migrate(migrations_path, version)
      
      branch_versions[branch_name][:end] = ActiveRecord::Migrator.current_version
      
      puts "branch_versions: #{branch_versions.inspect}"
      puts "Finished migrating branch #{branch_name}"
    end
    
    puts "Finished migrating through branches:#{branches.map{ | element | element.to_s.empty? ? "default" : element }.join( ", " )}"
    
    Rake::Task["db:schema:dump"].invoke if ActiveRecord::Base.schema_format == :ruby

#    #
#    puts "Loading default data for branches: #{branches.inspect}"
#    #
#    branches.each do | branch |
#      branch_name, target_version = ( branch.nil? ? [ nil, nil ] : branch.to_s.split( ':' ) )
#      branch_name = nil if branch_name == "default"
#
#      next unless branch_versions[branch_name][:start] == 0 && branch_versions[branch_name][:end] > 0
#      
#      "Loading default data from db/data/#{branch_name}".log(:header)
#
#      #if starting version was 0 and migrations were run successfully
#      #  load "db/data/branch_name/*.{yaml,csv}"
#      #  include "db/data/branch_name/branch_name.rb" # runs the class
#      #end
#      
#      require "active_record/fixtures"
#      ActiveRecord::Base.establish_connection( RAILS_ENV.to_sym )
#      if branch_name.nil?
#        data_files = Dir.glob( File.join( RAILS_ROOT, "db", "data", "*.{yaml,rb}" ) )
#      else
#        data_files = Dir.glob( File.join( RAILS_ROOT, "db", "data", branch_name, "*.yaml" ) )
#      end
#      
#      if ActiveRecord::Migrator.current_version == 0
#        ( data_files || [ ] ).each do | data_file |
#          if data_file.match /.*_join_.*/
#            MigrationBranches::DataLoader.load_join_table_data_from_file( data_file )
#          else
#            Fixtures.create_fixtures( "db/data#{'/' + branch_name if branch_name}", File.basename( data_file, ".*" ) )
#          end
#        end
#      end
#      
#      puts ""
#    end
  end

  namespace :migrate do
    # rake db:migrate:list_branch
    desc "List all branches."
    task :list_branches => :environment do
      branches =  ( `cd #{Dir.pwd}/db/migrate; ls -d */` ).gsub( /\/$/, '' ).split( "\n" )
      puts "Branches:\n\tdefault"
      branches.each { | branch_name | puts("\t#{branch_name}") }
    end
  end
end
