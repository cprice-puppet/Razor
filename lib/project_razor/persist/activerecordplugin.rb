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

        coll_id = get_collection_id(collection_name)

        record = ActiveRecordModel::Record.where(:uid => object_doc["@uuid"]).first

        if (record.nil?)
          record = ActiveRecordModel::Record.create(
              :uid => object_doc["@uuid"],
              :coll_id => coll_id,
              :version => 1
          )
        else
          record = ActiveRecordModel::Record.update(
              record.id,
              :uid => object_doc["@uuid"],
              :coll_id => coll_id,
              :version => record.version + 1
          )
        end

        # TODO: this is probably not be the most efficient way to do this; if
        #  some of the properties haven't changed then we don't really need to
        #  delete and recreate them, but I'm just trying to get something working.
        ActiveRecordModel::Property.delete_all(:record_id => record.id)

        object_doc.each_pair do |key, value|
          # we're storing uuid/version in the record table, so we don't need to
          #  store them here.
          next if ["@uuid", "@version"].include?(key)
          ActiveRecordModel::Property.create(
              :record_id => record.id,
              :name => key,
              # serializing the value to json in case it is a hash or other
              #  complex data type.  Due to some awesomeness with Ruby's
              #  JSON library, we have to wrap the value in an Array
              #  before serializing; otherwise, if the original value
              #  was a simple/scalar data type, Ruby's JSON will crap out
              #  when attempt to deserialize it.
              :value => [value].to_json
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

        coll_id = get_collection_id(collection_name)

        # TODO: not efficient; should use a join so this would
        #  only be one query.  Just trying to get something working.

        results = []
        ActiveRecordModel::Record.where(:coll_id => coll_id).each do |record|
          results << build_record_hash(record)
        end

        return results
      end


      def object_doc_get_by_uuid(object_doc, collection_name)
        logger.debug "Get document from collection (#{collection_name}) with uuid (#{object_doc['@uuid']})"

        record = ActiveRecordModel::Record.where(:uid => object_doc["@uuid"]).first
        return build_record_hash(record)
      end


      # Removes all documents from collection: 'collection_name' with 'uuid' in 'object_doc''
      # @param object_doc [Hash]
      # @param collection_name [Symbol]
      # @return [true, Hash] - returns 'true' if successful, otherwise returns 'Hash' with last error
      def object_doc_remove(object_doc, collection_name)
        logger.debug "Remove document in collection (#{collection_name}) with uuid (#{object_doc['@uuid']})"

        coll_id = get_collection_id(collection_name)

        record = ActiveRecordModel::Record.where(:uid => object_doc["@uuid"]).first
        ActiveRecordModel::Property.delete_all(:record_id => record.id)
        ActiveRecordModel::Record.delete(record.id)

        return true
      end


      def object_doc_remove_all(collection_name)
        logger.debug "Remove all documents in collection (#{collection_name})"
        coll_id = get_collection_id(collection_name)

        # TODO: inefficient.  To make this operation faster we could use some
        #  nested raw SQL, or potentially add a "coll_id" field to the property
        #  table.
        record_uids =
            ActiveRecordModel::Record.where(
                :coll_id => coll_id
            ).collect { |record| record.uid }

        record_uids.each do |record_uid|
          object_doc_remove({"@uuid" => record_uid}, :collection_name)
        end
      end


      def get_collection_id(collection_name)
        # TODO: inefficient, this method is only here so that we can cache these results
        #  and we are not caching them yet.
        coll = ActiveRecordModel::Collection.where("name = ?", collection_name).first_or_create(:name => collection_name)
        return coll.id
      end
      private :get_collection_id

      def build_record_hash(record)
        result = {
            "@uuid" => record.uid,
            "@version" => record.version,
        }
        ActiveRecordModel::Property.where(:record_id => record.id).each do |prop|
          # All property values are single-value arrays serialized to JSON;
          #  This allows us to store Hashes and other complex data into a String
          #  field in the database.  The reason they are stored as single-element
          #  arrays is because Ruby's JSON library will crap out if you try
          #  to serialize and then deserialize a simple/scalar data type like
          #  a string or an integer.
          result[prop.name] = JSON.parse(prop.value).first
        end
        return result
      end
      private :build_record_hash

    end
  end
end