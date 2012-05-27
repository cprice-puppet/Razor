require 'active_record'

module ProjectRazor
  module Persist
    module ActiveRecordModel
      class Collection < ActiveRecord::Base
        # TODO: centralize this config stuff
        configurations['razor'] = {
            'adapter' => 'postgresql',
            'database' => 'razor',
            'username' => 'razor',
            'password' => 'razor',
        }
        establish_connection 'razor'
        attr_accessible :id, :name

        validates_presence_of :name
      end
    end
  end
end
