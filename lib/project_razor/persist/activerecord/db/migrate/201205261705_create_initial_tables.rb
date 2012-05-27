class CreateInitialTables < ActiveRecord::Migration
  def self.up
    create_table :collections do |c|
      c.string :name
    end

    create_table :records do |r|
      # TODO: index uid and coll_id
      r.string :uid
      r.integer :coll_id
      r.integer :version
    end

    create_table :properties do |p|
      # TODO: index record_id and name
      p.integer :record_id
      p.string :name
      p.string :value
    end

  #  create_table :users do |t|
  #    t.string :email
  #    t.string :encrypted_password
  #    t.string :encryption_salt
  #    t.string :status
  #
  #    t.timestamps
  #  end
  #
  #  #create_table :roles do |t|
  #  #  t.string :name
  #  #end
  #  #
  #  #create_table :roles_users, :id => false do |t|
  #  #  t.references :role, :user
  #  #end
  end

  def self.down
  #  drop_table :users
  #  #drop_table :roles
    drop_table :collections
  end
end

