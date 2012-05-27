require 'active_record'

module ProjectRazor
  module Persist
    module ActiveRecordModel
      class Record < ActiveRecord::Base
        # TODO: centralize this config stuff
        configurations['razor'] = {
            'adapter' => 'postgresql',
            'database' => 'razor',
            'username' => 'razor',
            'password' => 'razor',
        }
        establish_connection 'razor'
        attr_accessible :id, :uid, :coll_id, :version

        validates_presence_of :uid, :coll_id, :version
      end
    end
  end
end