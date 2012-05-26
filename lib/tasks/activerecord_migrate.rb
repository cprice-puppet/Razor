require 'logger'

namespace :activerecord do
    desc "Migrate the database"
    task :migrate  => :connect do
        ActiveRecord::Base.logger = Logger.new(STDOUT)
        ActiveRecord::Migration.verbose = true
        ActiveRecord::Migrator.migrate('lib/project_razor/persist/activerecord/db/migrate')
    end
end
