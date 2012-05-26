namespace :activerecord do
    desc "Connect to the database"
    task :connect do
        require 'active_record'
        env = ENV['RACK_ENV'] || ENV['RAILS_ENV'] || 'production'
        #dbconfig = YAML::load(File.open activerecord_db_config)[env]
        #ActiveRecord::Base.configurations['razor'] = dbconfig
        ActiveRecord::Base.configurations['razor'] = {
            'adapter' => 'postgresql',
            'database' => 'razor',
            'username' => 'razor',
            'password' => 'razor',
        }
        #require 'models/role'
        #require 'models/user'
        #require 'models/activation'
        ActiveRecord::Base.establish_connection 'razor'
    end
end

