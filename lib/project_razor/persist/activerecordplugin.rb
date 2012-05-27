require 'active_record'
require 'project_razor/persist/activerecord/db/model/collection'
require 'project_razor/persist/activerecord/db/model/record'
require 'project_razor/persist/activerecord/db/model/property'

module ProjectRazor
  module Persist
    class ActiveRecordPlugin
      include(ProjectRazor::Logging)

      def initialize()
        #puts "ACTIVERECORDPLUGIN.initialize"
        #@hacky_temp_collection_map = {}
      end

      # Establishes ActiveRecord db connection
      def connect(hostname, port, timeout)
        # TODO: we need to standardize the signature of this method, because
        #  the inputs needed for the Mongo connection are not the same as
        #  for the activerecord connection.
        # For now I'm just going to ignore the parameters that are passed in,
        #  and hard-code the activerecord connection info.  This needs to
        #  be fixed.

        #puts "In ActiveRecordPlugin.connect"
        ActiveRecord::Base.configurations['razor'] = {
            'adapter' => 'postgresql',
            'database' => 'razor',
            'username' => 'razor',
            'password' => 'razor',
        }
        ActiveRecord::Base.establish_connection 'razor'
        @connection = ActiveRecord::Base.connection
        #puts "Seems like we've connected successfully'"
        #puts "Connected?: #{ActiveRecord::Base.connected?}"
      end


      # Closes connection if it is active
      def teardown
        # TODO: I'm pretty sure this is not the right way to use ActiveRecord. :)
        #puts "Closing connection"
        ActiveRecord::Base.remove_connection
      end

      def is_db_selected?()
        return ActiveRecord::Base.connected?
      end

      ## From [Array] of documents return [Array] containing newest/unique documents
      ## this also takes all older/duplicate documents and calls [cleanup_old_documents] to remove them
      ## @param collection_name [Symbol]
      ## @return [Array]
      #def object_doc_get_all(collection_name)
      #  puts "Get all documents from collection (#{collection_name})"
      #
      #end

      # Adds object document to the collection with an incremented "@version" key
      # @param object_doc [Hash]
      # @param collection_name [Symbol]
      # @return [Hash] - returns the updated [Hash] of doc
      def object_doc_update(object_doc, collection_name)
        logger.debug "Update document in collection (#{collection_name}) with uuid (#{object_doc['@uuid']})"
        #puts "Update document in collection (#{collection_name}) with uuid (#{object_doc['@uuid']})"
        #require 'pp'
        #pp object_doc
        coll = get_collection(collection_name)


        record = ActiveRecordModel::Record.where(:uid => object_doc["@uuid"]).first


        #coll_hash = get_collection_hash(coll)
        #next_version = 1
        #if (coll_hash.has_key?(object_doc["@uuid"]))
        #  next_version = coll_hash[object_doc["@uuid"]]["@version"] + 1
        #end
        #object_doc["@version"] = next_version
        #coll_hash[object_doc["@uuid"]] = object_doc

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




        #puts "COLLECTION SIZE IS NOW: '#{get_collection(collection_name).size}'"
        return object_doc
        ## Add a timestamp key
        ## We use this to always pull newest
        #object_doc["@version"] = get_next_version(object_doc, collection_name)
        #collection_by_name(collection_name).insert(object_doc)
        #object_doc
      end

      # From [Array] of documents return [Array] containing newest/unique documents
      # this also takes all older/duplicate documents and calls [cleanup_old_documents] to remove them
      # @param collection_name [Symbol]
      # @return [Array]
      def object_doc_get_all(collection_name)
        #logger.debug "Get all documents from collection (#{collection_name})"
        #puts "Get all documents from collection (#{collection_name})"
        coll = get_collection(collection_name)
        #get_collection_hash(coll).values

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



        #unique_object_doc_array = []  # [Array] to hold new/unique docs
        #old_object_doc_array = []  # [Array] to hold old/duplicate docs
        #
        ## Get all docs from 'collection_name' Collection and sort Desc by 'version'
        #collection_by_name(collection_name).find().sort("@version",-1).each do
        #  # Iterate over each doc
        #|object_doc_in_coll|
        #
        #  flag = false # Set flag to false, if flag is true: doc is a duplicate
        #
        #  # Iterate over our unique doc [Array]
        #  unique_object_doc_array.each do
        #  |existing_unique_object_doc|
        #
        #    # If an existing unique doc matches the 'uuid' of a collection doc it is old
        #    if existing_unique_object_doc["@uuid"] == object_doc_in_coll["@uuid"]
        #      flag =  true # duplicate found because it is already in our unique [Array]
        #    end
        #  end
        #
        #  if flag
        #    # Flag = true means this is a duplicate. We add it to our old object doc array
        #    old_object_doc_array << object_doc_in_coll
        #  else
        #    # Flag = false means this is the first time we have seen this one. We add it to the unique object doc array
        #    unique_object_doc_array << object_doc_in_coll
        #  end
        #end
        #
        #cleanup_old_docs(old_object_doc_array, collection_name) # we send old docs to get removed
        #remove_mongo_keys(unique_object_doc_array) # we return our unique/new docs after removing mongo-related keys (_id, _timestamp)
      end


      # Removes all documents from collection: 'collection_name' with 'uuid' in 'object_doc''
      # @param object_doc [Hash]
      # @param collection_name [Symbol]
      # @return [true, Hash] - returns 'true' if successful, otherwise returns 'Hash' with last error
      def object_doc_remove(object_doc, collection_name)
        #logger.debug "Remove document in collection (#{collection_name}) with uuid (#{object_doc['@uuid']})"
        #puts "Remove document in collection (#{collection_name}) with uuid (#{object_doc['@uuid']})"
        #while collection_by_name(collection_name).find({"@uuid" => object_doc["@uuid"]}).count > 0
        #  unless collection_by_name(collection_name).remove({"@uuid" => object_doc["@uuid"]})
        #    return false
        #  end
        #end
        #true
        coll = get_collection(collection_name)
        #get_collection_hash(coll).delete(object_doc['@uuid'])

        record = ActiveRecordModel::Record.where(:uid => object_doc["@uuid"]).first
        ActiveRecordModel::Property.delete_all(:record_id => record.id)
        ActiveRecordModel::Record.delete(record.id)

        return true
      end



      #### TODO: this is a temporary hack, will go away once we actually
      # start persisting all of this stuff.
      def get_collection(collection_name)
        # TODO: inefficient, should cache these results
        coll = ActiveRecordModel::Collection.where("name = ?", collection_name).first_or_create(:name => collection_name)
        #if (coll.empty?)
        #  pp "NO COLLECTION"
        #  ActiveRecordModel::Collection.save
        #else
        #  require 'pp'
        #  pp coll
        #end
        return coll
      end

      #def get_collection_hash(coll)
      #  unless @hacky_temp_collection_map.has_key?(coll.name)
      #    #puts "Creating new entry in hacky temp collection (#{collection_name}"
      #    @hacky_temp_collection_map[coll.name] = {}
      #  end
      #  @hacky_temp_collection_map[coll.name]
      #end


    end
  end
end