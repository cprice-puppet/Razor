require 'active_record'

module ProjectRazor
  module Persist
    module ActiveRecordModel
      class Property < ActiveRecord::Base
        # TODO: centralize this config stuff
        configurations['razor'] = {
            'adapter' => 'postgresql',
            'database' => 'razor',
            'username' => 'razor',
            'password' => 'razor',
        }
        establish_connection 'razor'
        attr_accessible :id, :record_id, :name, :value

        validates_presence_of :record_id, :name, :value
      end
    end
  end
end