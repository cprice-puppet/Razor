require 'active_record'
require 'project_razor/persist/activerecord/db/model/collection'
require 'project_razor/persist/activerecord/db/model/record'
require 'project_razor/persist/activerecord/db/model/property'

module ProjectRazor
  module Persist
    class ActiveRecordPlugin
      include(ProjectRazor::Logging)

      # Establishes ActiveRecord db connection
      def connect(hostname, port, timeout)
        # TODO: we need to standardize the signature of this method, because
        #  the inputs needed for the Mongo connection are not the same as
        #  for the activerecord connection.
        # For now I'm just going to ignore the parameters that are passed in,
        #  and hard-code the activerecord connection info.  This needs to
        #  be fixed.

        ActiveRecord::Base.configurations['razor'] = {
            'adapter' => 'postgresql',
            'database' => 'razor',
            'username' => 'razor',
            'password' => 'razor',
        }
        ActiveRecord::Base.establish_connection 'razor'
        @connection = ActiveRecord::Base.connection
      end


      # Closes connection if it is active
      def teardown
        # TODO: I'm pretty sure this is not the right way to use ActiveRecord. :)
        ActiveRecord::Base.remove_connection
      end

      def is_db_selected?()
        return ActiveRecord::Base.connected?
      end


      # Adds object document to the collection with an incremented "@version" key
      # @param object_doc [Hash]
      # @param collection_name [Symbol]
      # @return [Hash] - returns the updated [Hash] of doc
      def object_doc_update(object_doc, collection_name)
        logger.debug "Update document in collection (#{collection_name}) with uuid (#{object_doc['@uuid']})"

        coll = get_collection(collection_name)

        record = ActiveRecordModel::Record.where(:uid => object_doc["@uuid"]).first

        if (record.nil?)
          record = ActiveRecordModel::Record.create(
              :uid => object_doc["@uuid"],
              :coll_id => coll.id,
              :version => 1,
          )
        else
          record = ActiveRecordModel::Record.update(
              record.id,
              :uid => object_doc["@uuid"],
              :coll_id => coll.id,
              :version => record.version + 1,
          )
        end

        # TODO: this is probably not be the most efficient way to do this; if
        #  some of the properties haven't changed then we don't really need to
        #  delete and recreate them, but I'm just trying to get something working.
        ActiveRecordModel::Property.delete_all(:record_id => record.id)

        object_doc.each_pair do |key, value|
          next if ["@uuid", "@version"].include?(key)
          # TODO: need to serialize the value in case it is a hash or something
          ActiveRecordModel::Property.create(
              :record_id => record.id,
              :name => key,
              :value => value,
          )
        end
        return object_doc
      end

      # From [Array] of documents return [Array] containing newest/unique documents
      # this also takes all older/duplicate documents and calls [cleanup_old_documents] to remove them
      # @param collection_name [Symbol]
      # @return [Array]
      def object_doc_get_all(collection_name)
        logger.debug "Get all documents from collection (#{collection_name})"

        coll = get_collection(collection_name)

        # TODO: not efficient; should use a join so this would
        #  only be one query.  Just trying to get something working.

        results = []
        ActiveRecordModel::Record.where(:coll_id => coll.id).each do |record|
          result = {
              "@uuid" => record.uid,
              "@version" => record.version,
          }
          ActiveRecordModel::Property.where(:record_id => record.id).each do |prop|
            result[prop.name] = prop.value
          end

          results << result
        end

        return results
      end


      # Removes all documents from collection: 'collection_name' with 'uuid' in 'object_doc''
      # @param object_doc [Hash]
      # @param collection_name [Symbol]
      # @return [true, Hash] - returns 'true' if successful, otherwise returns 'Hash' with last error
      def object_doc_remove(object_doc, collection_name)
        logger.debug "Remove document in collection (#{collection_name}) with uuid (#{object_doc['@uuid']})"

        coll = get_collection(collection_name)

        record = ActiveRecordModel::Record.where(:uid => object_doc["@uuid"]).first
        ActiveRecordModel::Property.delete_all(:record_id => record.id)
        ActiveRecordModel::Record.delete(record.id)

        return true
      end



      #### TODO: this is a temporary hack, will go away once we actually
      # start persisting all of this stuff.
      def get_collection(collection_name)
        # TODO: inefficient, this method is only here so that we can cache these results
        #  and we are not caching them yet.
        coll = ActiveRecordModel::Collection.where("name = ?", collection_name).first_or_create(:name => collection_name)
        return coll
      end

    end
  end
end