class LoadSchema
  attr_reader :schema

  # XMEN
  def initialize
    @unique_keys = {}
    @current_table = nil
    @rails_version = 4
    @schema = {
      tables: [],
      foreign_keys: [],
      indexes: [],
      views: [],
      meta: {
        rails: @rails_version,
        db_info: {
          type: 'postgres',
          version: nil,         # TODO
          extensions: []
        },
        unique_keys: []
      }
    }
  end

  # ----------------------------------------------------------------------
  # Inject start
  # original file: spec/example_domain/simple/input/schema.rb
  # ----------------------------------------------------------------------
  def load_schema
    # frozen_string_literal: true
    
    # This file was generated from an ASP.net database schema, note any relational DB can be used.
    
    # The tool used to generate this schema was a Rails tool "rake db:schema:dump"
    
    # The information in this file is a rich replica for the Relational DB and will be used as the
    # input source for the domain model
    load(version: 0) do
      # These are extensions that must be enabled in order to support this database
      enable_extension 'plpgsql'
    
      create_table '__EFMigrationsHistory', primary_key: 'MigrationId', force: :cascade do |t|
        t.string 'ProductVersion', limit: 32, null: false
      end
    
      # This is for testing ERD DSL
      create_table 'samples', force: :cascade do |t|
        t.boolean 'deleted', null: false
        t.integer 'app_user_id', null: false
        t.integer 'sales_user_id', null: false
        t.float   'longitude',   null: false
        t.float   'latitude',    null: false
        t.text    'name'
        t.text    'address'
        t.integer 'shop_id', null: false
        t.integer 'user_id', null: false
        t.text    'type'
      end
    
      create_table 'app_users', force: :cascade do |t|
        t.text 'user_id'
        t.text 'first_name'
        t.text 'last_name'
        t.text 'phone_number'
      end
    
      add_index 'app_users', ['user_id'], name: 'IX_app_users_user_id', using: :btree
    
      create_table 'asp_net_role_claims', force: :cascade do |t|
        t.text 'role_id', null: false
        t.text 'claim_type'
        t.text 'claim_value'
      end
    
      add_index 'asp_net_role_claims', ['role_id'], name: 'IX_asp_net_role_claims_role_id', using: :btree
    
      create_table 'asp_net_roles', force: :cascade do |t|
        t.string 'name',              limit: 256
        t.string 'normalized_name',   limit: 256
        t.text   'concurrency_stamp'
      end
    
      add_index 'asp_net_roles', ['normalized_name'], name: 'RoleNameIndex', unique: true, using: :btree
    
      create_table 'asp_net_user_claims', force: :cascade do |t|
        t.text 'user_id', null: false
        t.text 'claim_type'
        t.text 'claim_value'
      end
    
      add_index 'asp_net_user_claims', ['user_id'], name: 'IX_asp_net_user_claims_user_id', using: :btree
    
      create_table 'asp_net_user_logins', id: false, force: :cascade do |t|
        t.string 'login_provider',        limit: 128, null: false
        t.string 'provider_key',          limit: 128, null: false
        t.text   'provider_display_name'
        t.text   'user_id', null: false
      end
    
      add_index 'asp_net_user_logins', ['user_id'], name: 'IX_asp_net_user_logins_user_id', using: :btree
    
      create_table 'asp_net_user_roles', id: false, force: :cascade do |t|
        t.text 'user_id', null: false
        t.text 'role_id', null: false
      end
    
      add_index 'asp_net_user_roles', ['role_id'], name: 'IX_asp_net_user_roles_role_id', using: :btree
    
      create_table 'asp_net_user_tokens', id: false, force: :cascade do |t|
        t.text   'user_id',                    null: false
        t.string 'login_provider', limit: 128, null: false
        t.string 'name',           limit: 128, null: false
        t.text   'value'
      end
    
      create_table 'asp_net_users', force: :cascade do |t|
        t.string   'user_name',              limit: 256
        t.string   'normalized_user_name',   limit: 256
        t.string   'email',                  limit: 256
        t.string   'normalized_email',       limit: 256
        t.boolean  'email_confirmed', null: false
        t.text     'password_hash'
        t.text     'security_stamp'
        t.text     'concurrency_stamp'
        t.text     'phone_number'
        t.boolean  'phone_number_confirmed',             null: false
        t.boolean  'two_factor_enabled',                 null: false
        t.datetime 'lockout_end'
        t.boolean  'lockout_enabled',                    null: false
        t.integer  'access_failed_count',                null: false
      end
    
      add_index 'asp_net_users', ['normalized_email'], name: 'EmailIndex', using: :btree
      add_index 'asp_net_users', ['normalized_user_name'], name: 'UserNameIndex', unique: true, using: :btree
    
      create_table 'customer_shops', force: :cascade do |t|
        t.integer 'status',      null: false
        t.integer 'customer_id', null: false
        t.integer 'shop_id',     null: false
      end
    
      add_index 'customer_shops', ['customer_id'], name: 'IX_customer_shops_customer_id', using: :btree
      add_index 'customer_shops', ['shop_id'], name: 'IX_customer_shops_shop_id', using: :btree
    
      create_table 'favourite_orders', force: :cascade do |t|
        t.integer 'customer_id'
        t.integer 'order_id'
      end
    
      add_index 'favourite_orders', ['customer_id'], name: 'IX_favourite_orders_customer_id', using: :btree
      add_index 'favourite_orders', ['order_id'], name: 'IX_favourite_orders_order_id', using: :btree
    
      create_table 'item_variations', force: :cascade do |t|
        t.integer 'item_id', null: false
        t.text    'name'
        t.boolean 'default',       null: false
        t.integer 'qty',           null: false
        t.text    'qty_variation'
      end
    
      add_index 'item_variations', ['item_id'], name: 'IX_item_variations_item_id', using: :btree
    
      create_table 'items', force: :cascade do |t|
        t.text 'title'
        t.text 'group'
      end
    
      create_table 'menu_categories', force: :cascade do |t|
        t.integer 'shop_id', null: false
        t.text    'name'
        t.integer 'position', null: false
      end
    
      add_index 'menu_categories', ['shop_id'], name: 'IX_menu_categories_shop_id', using: :btree
    
      create_table 'menu_category_products', force: :cascade do |t|
        t.integer 'menu_category_id', null: false
        t.integer 'product_id',       null: false
        t.integer 'position',         null: false
      end
    
      add_index 'menu_category_products', ['menu_category_id'], name: 'IX_menu_category_products_menu_category_id', using: :btree
      add_index 'menu_category_products', ['product_id'], name: 'IX_menu_category_products_product_id', using: :btree
    
      create_table 'orders', force: :cascade do |t|
        t.integer  'customer_id',   null: false
        t.integer  'shop_id',       null: false
        t.jsonb    'order_details'
        t.datetime 'placed_at',     null: false
        t.datetime 'in_queue_at',   null: false
        t.datetime 'making_at',     null: false
        t.datetime 'made_at',       null: false
        t.datetime 'cancelled_at',  null: false
        t.datetime 'collected_at',  null: false
        t.datetime 'fail_at',       null: false
        t.text     'fail_reason'
      end
    
      add_index 'orders', ['customer_id'], name: 'IX_orders_customer_id', using: :btree
      add_index 'orders', ['shop_id'], name: 'IX_orders_shop_id', using: :btree
    
      create_table 'product_variations', force: :cascade do |t|
        t.integer 'product_id',        null: false
        t.integer 'item_variation_id', null: false
        t.boolean 'active',            null: false
        t.text    'title'
        t.float   'price_offset', null: false
      end
    
      add_index 'product_variations', ['item_variation_id'], name: 'IX_product_variations_item_variation_id', using: :btree
      add_index 'product_variations', ['product_id'], name: 'IX_product_variations_product_id', using: :btree
    
      create_table 'products', force: :cascade do |t|
        t.integer 'shop_id', null: false
        t.text    'title'
        t.float   'price', null: false
      end
    
      add_index 'products', ['shop_id'], name: 'IX_products_shop_id', using: :btree
    
      create_table 'shops', force: :cascade do |t|
        t.integer 'app_user_id', null: false
        t.text    'name'
        t.text    'address'
        t.float   'longitude',   null: false
        t.float   'latitude',    null: false
      end
    
      add_index 'shops', ['app_user_id'], name: 'IX_shops_app_user_id', using: :btree
    
      create_table 'staffs', force: :cascade do |t|
        t.integer 'shop_id', null: false
        t.integer 'user_id', null: false
        t.text    'type'
      end
    
      add_index 'staffs', ['shop_id'], name: 'IX_staffs_shop_id', using: :btree
      add_index 'staffs', ['user_id'], name: 'IX_staffs_user_id', using: :btree
    
      add_foreign_key 'app_users', 'asp_net_users', column: 'user_id', name: 'fk_app_users_asp_net_users_user_id', on_delete: :restrict
      add_foreign_key 'asp_net_role_claims', 'asp_net_roles', column: 'role_id', name: 'fk_asp_net_role_claims_asp_net_roles_role_id', on_delete: :cascade
      add_foreign_key 'asp_net_user_claims', 'asp_net_users', column: 'user_id', name: 'fk_asp_net_user_claims_asp_net_users_user_id', on_delete: :cascade
      add_foreign_key 'asp_net_user_logins', 'asp_net_users', column: 'user_id', name: 'fk_asp_net_user_logins_asp_net_users_user_id', on_delete: :cascade
      add_foreign_key 'asp_net_user_roles', 'asp_net_roles', column: 'role_id', name: 'fk_asp_net_user_roles_asp_net_roles_role_id', on_delete: :cascade
      add_foreign_key 'asp_net_user_roles', 'asp_net_users', column: 'user_id', name: 'fk_asp_net_user_roles_asp_net_users_user_id', on_delete: :cascade
      add_foreign_key 'asp_net_user_tokens', 'asp_net_users', column: 'user_id', name: 'fk_asp_net_user_tokens_asp_net_users_user_id', on_delete: :cascade
      add_foreign_key 'customer_shops', 'app_users', column: 'customer_id', name: 'fk_customer_shops_app_users_customer_id', on_delete: :cascade
      add_foreign_key 'customer_shops', 'shops', name: 'fk_customer_shops_shops_shop_id', on_delete: :cascade
      add_foreign_key 'favourite_orders', 'app_users', column: 'customer_id', name: 'fk_favourite_orders_app_users_customer_id', on_delete: :restrict
      add_foreign_key 'favourite_orders', 'orders', name: 'fk_favourite_orders_orders_order_id', on_delete: :restrict
      add_foreign_key 'item_variations', 'items', name: 'fk_item_variations_items_item_id', on_delete: :cascade
      add_foreign_key 'menu_categories', 'shops', name: 'fk_menu_categories_shops_shop_id', on_delete: :cascade
      add_foreign_key 'menu_category_products', 'menu_categories', name: 'fk_menu_category_products_menu_categories_menu_category_id', on_delete: :cascade
      add_foreign_key 'menu_category_products', 'products', name: 'fk_menu_category_products_products_product_id', on_delete: :cascade
      add_foreign_key 'orders', 'app_users', column: 'customer_id', name: 'fk_orders_app_users_customer_id', on_delete: :cascade
      add_foreign_key 'orders', 'shops', name: 'fk_orders_shops_shop_id', on_delete: :cascade
      add_foreign_key 'product_variations', 'item_variations', name: 'fk_product_variations_item_variations_item_variation_id', on_delete: :cascade
      add_foreign_key 'product_variations', 'products', name: 'fk_product_variations_products_product_id', on_delete: :cascade
      add_foreign_key 'products', 'shops', name: 'fk_products_shops_shop_id', on_delete: :cascade
      add_foreign_key 'shops', 'app_users', name: 'fk_shops_app_users_app_user_id', on_delete: :cascade
      add_foreign_key 'staffs', 'app_users', column: 'user_id', name: 'fk_staffs_app_users_user_id', on_delete: :cascade
      add_foreign_key 'staffs', 'shops', name: 'fk_staffs_shops_shop_id', on_delete: :cascade
    end

  end

  # ----------------------------------------------------------------------
  # original file: spec/example_domain/simple/input/schema.rb
  # Inject end
  # ----------------------------------------------------------------------

  def write_json(file)
    schema[:meta][:rails] = @rails_version
    File.write(file, JSON.pretty_generate(schema))
  end

  # This is the rails timestamp and will be replaced by the action rails version
  def load(version:)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    # puts 'about to load'
    yield if block_given?

    schema[:meta][:rails] = @rails_version

    sort
    # code to time

    # log.kv 'extensions', schema[:db_info][:extensions].length
    # log.kv 'tables', schema[:tables].length
    # log.kv 'indexes', schema[:indexes].length  
    # # a low foreign_keys count is indicative of not using SQL referential integrity
    # log.kv 'foreign_keys', schema[:foreign_keys].length
    # log.kv 'Time Taken', (finish - start)

    # puts schema[:db_info][:extensions]
    # print_unique_keys(type: :foreign_keys, title: 'unique options for foreign_keys')
    # print_unique_keys(type: :columns, title: 'unique options for columns')
    # print_unique_keys(type: :fields, category: :integer , title: 'unique options for column - integer')
    # print_unique_keys(type: :fields, category: :decimal , title: 'unique options for column - decimal')
    # print_unique_keys(type: :fields, category: :string  , title: 'unique options for column - string')
    # print_unique_keys(type: :fields, category: :datetime, title: 'unique options for column - datetime')
    # print_unique_keys(type: :fields, category: :date    , title: 'unique options for column - date')
    # print_unique_keys(type: :fields, category: :text    , title: 'unique options for column - text')
    # print_unique_keys(type: :fields, category: :boolean , title: 'unique options for column - boolean')
    # print_unique_keys(type: :fields, category: :jsonb   , title: 'unique options for column - jsonb')
    # print_unique_keys(type: :fields, category: :hstore  , title: 'unique options for column - hstore')
    # print_unique_keys(type: :fields, category: :float   , title: 'unique options for column - float')
  end

  def enable_extension(name)
    # puts "enable_extension(#{name})"
    schema[:meta][:db_info][:extensions] << name
  end

  def create_table(name, **opts)
    id = opts[:id]
    primary_key = opts[:primary_key] || (id == false ? nil : "id")
    primary_key_type = if id == false
                         nil
                       elsif id.nil?
                         "bigint"
                       else
                         id
                       end

    @current_table = {
      name: name,
      primary_key: primary_key,                           # infer the actual value that should be in the database
      primary_key_type: primary_key_type,                 # infer the actual value that should be in the database
      columns: [],
      indexes: [],
      rails_schema: {                                     # as reported by the rails schema
        primary_key: opts[:primary_key],
        id: id,
        force: opts[:force]
      }
    }
    # schema[:tables][name] = @current_table
    schema[:tables] << @current_table
    
    yield(self) if block_given?
  end

  def add_field(name, type, **opts)
    # puts "add_field(#{name}, #{type})"
    row = { name: name, type: type, **opts }
    @current_table[:columns] << row

    add_unique_keys(row.keys, type: :columns)
    add_unique_keys(row.keys, type: :fields, category: type)
  end

  def add_index(name, fields, **opts)
    # puts "add_index(#{name})"
    row = { name: name, fields: fields, **opts }
    @current_table[:indexes] << row
    schema[:indexes] << row
    add_unique_keys(row.keys, type: :indexes)
  end

  # This method was introduced onto the schema in rails 5
  def index(fields, **opts)
    @rails_version = 5
    name = opts[:name]
    opts.delete(:name)
    add_index(name, fields, **opts)
  end

  def create_view(name, **opts)
    row = { name: name, **opts }
    schema[:views] << row
    add_unique_keys(row.keys, type: :views)
  end

  def add_foreign_key(left_table, right_table, **opts)
    # puts "add_foreign_key(#{left_table}, #{right_table})"
    row = { left: left_table, right: right_table, **opts }
    schema[:foreign_keys] << row
    add_unique_keys(row.keys, type: :foreign_keys)
  end

  def add_unique_keys(keys, type:, category: nil)
    key = [type, category, keys.join('-')].compact.join('|')
    return if @unique_keys.key?(key)

    @unique_keys[key] = key
    schema[:meta][:unique_keys] << { type: type, category: category, key: keys.join(','), keys: keys }
  end

  def print_unique_keys(type:, category: nil, title: )
    log.section_heading(title)

    filter_key_infos = schema[:meta][:unique_keys].select { |key_info| key_info[:type] == type && (category.nil? || key_info[:category] == category) }

    # log.kv 'all', filter_key_infos.flat_map { |key_info| key_info[:keys] }.uniq, 50

    filter_key_infos.each do |key_info|
      log.kv key_info[:key], key_info[:keys], 50
    end
  end

  def integer(name, **opts)
    add_field(name, :integer, **opts)
  end

  def bigint(name, **opts)
    add_field(name, :bigint, **opts)
  end

  def decimal(name, **opts)
    add_field(name, :decimal, **opts)
  end

  def string(name, **opts)
    add_field(name, :string, **opts)
  end

  def datetime(name, **opts)
    add_field(name, :datetime, **opts)
  end

  def date(name, **opts)
    add_field(name, :date, **opts)
  end

  def text(name, **opts)
    add_field(name, :text, **opts)
  end

  def boolean(name, **opts)
    add_field(name, :boolean, **opts)
  end

  def jsonb(name, **opts)
    add_field(name, :jsonb, **opts)
  end

  def hstore(name, **opts)
    add_field(name, :hstore, **opts)
  end

  def float(name, **opts)
    add_field(name, :float, **opts)
  end

  def sort
    schema[:indexes].sort_by! { |i| i[:name] }
    schema[:tables].each { |table| table[:indexes].sort_by! { |i| i[:name] } }

    # Insert a key that represents all unique keys, and then sort
    unique_keys_per_group = schema[:meta][:unique_keys]
      .group_by { |key_info| [key_info[:type], key_info[:category]] }
      .map do |group, values|
        all_keys = values.flat_map { |key_info| key_info[:keys] }.uniq
        { 
          type: group[0],
          category: group[01],
          key: 'all',
          keys: all_keys
        }
      end

    schema[:meta][:unique_keys].concat(unique_keys_per_group)
    schema[:meta][:unique_keys].sort! { |a,b| ([a[:type], a[:category],a[:key]] <=> [b[:type], b[:category],b[:key]]) }
  end
end
