# This file was generated from an ASP.net database schema, note any relational DB can be used.

# The tool used to generate this schema was a Rails tool "rake db:schema:dump"

# The information in this file is a rich replica for the Relational DB and will be used as the
# input source for the domain model
ActiveRecord::Schema.define(version: 0) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "__EFMigrationsHistory", primary_key: "MigrationId", force: :cascade do |t|
    t.string "ProductVersion", limit: 32, null: false
  end

  create_table "app_users", force: :cascade do |t|
    t.text "user_id"
    t.text "first_name"
    t.text "last_name"
    t.text "phone_number"
  end

  add_index "app_users", ["user_id"], name: "IX_app_users_user_id", using: :btree

  create_table "asp_net_role_claims", force: :cascade do |t|
    t.text "role_id",     null: false
    t.text "claim_type"
    t.text "claim_value"
  end

  add_index "asp_net_role_claims", ["role_id"], name: "IX_asp_net_role_claims_role_id", using: :btree

  create_table "asp_net_roles", force: :cascade do |t|
    t.string "name",              limit: 256
    t.string "normalized_name",   limit: 256
    t.text   "concurrency_stamp"
  end

  add_index "asp_net_roles", ["normalized_name"], name: "RoleNameIndex", unique: true, using: :btree

  create_table "asp_net_user_claims", force: :cascade do |t|
    t.text "user_id",     null: false
    t.text "claim_type"
    t.text "claim_value"
  end

  add_index "asp_net_user_claims", ["user_id"], name: "IX_asp_net_user_claims_user_id", using: :btree

  create_table "asp_net_user_logins", id: false, force: :cascade do |t|
    t.string "login_provider",        limit: 128, null: false
    t.string "provider_key",          limit: 128, null: false
    t.text   "provider_display_name"
    t.text   "user_id",                           null: false
  end

  add_index "asp_net_user_logins", ["user_id"], name: "IX_asp_net_user_logins_user_id", using: :btree

  create_table "asp_net_user_roles", id: false, force: :cascade do |t|
    t.text "user_id", null: false
    t.text "role_id", null: false
  end

  add_index "asp_net_user_roles", ["role_id"], name: "IX_asp_net_user_roles_role_id", using: :btree

  create_table "asp_net_user_tokens", id: false, force: :cascade do |t|
    t.text   "user_id",                    null: false
    t.string "login_provider", limit: 128, null: false
    t.string "name",           limit: 128, null: false
    t.text   "value"
  end

  create_table "asp_net_users", force: :cascade do |t|
    t.string   "user_name",              limit: 256
    t.string   "normalized_user_name",   limit: 256
    t.string   "email",                  limit: 256
    t.string   "normalized_email",       limit: 256
    t.boolean  "email_confirmed",                    null: false
    t.text     "password_hash"
    t.text     "security_stamp"
    t.text     "concurrency_stamp"
    t.text     "phone_number"
    t.boolean  "phone_number_confirmed",             null: false
    t.boolean  "two_factor_enabled",                 null: false
    t.datetime "lockout_end"
    t.boolean  "lockout_enabled",                    null: false
    t.integer  "access_failed_count",                null: false
  end

  add_index "asp_net_users", ["normalized_email"], name: "EmailIndex", using: :btree
  add_index "asp_net_users", ["normalized_user_name"], name: "UserNameIndex", unique: true, using: :btree

  create_table "customer_shops", force: :cascade do |t|
    t.integer "status",      null: false
    t.integer "customer_id", null: false
    t.integer "shop_id",     null: false
  end

  add_index "customer_shops", ["customer_id"], name: "IX_customer_shops_customer_id", using: :btree
  add_index "customer_shops", ["shop_id"], name: "IX_customer_shops_shop_id", using: :btree

  create_table "favourite_orders", force: :cascade do |t|
    t.integer "customer_id"
    t.integer "order_id"
  end

  add_index "favourite_orders", ["customer_id"], name: "IX_favourite_orders_customer_id", using: :btree
  add_index "favourite_orders", ["order_id"], name: "IX_favourite_orders_order_id", using: :btree

  create_table "item_variations", force: :cascade do |t|
    t.integer "item_id",       null: false
    t.text    "name"
    t.boolean "default",       null: false
    t.integer "qty",           null: false
    t.text    "qty_variation"
  end

  add_index "item_variations", ["item_id"], name: "IX_item_variations_item_id", using: :btree

  create_table "items", force: :cascade do |t|
    t.text "title"
    t.text "group"
  end

  create_table "menu_categories", force: :cascade do |t|
    t.integer "shop_id",  null: false
    t.text    "name"
    t.integer "position", null: false
  end

  add_index "menu_categories", ["shop_id"], name: "IX_menu_categories_shop_id", using: :btree

  create_table "menu_category_products", force: :cascade do |t|
    t.integer "menu_category_id", null: false
    t.integer "product_id",       null: false
    t.integer "position",         null: false
  end

  add_index "menu_category_products", ["menu_category_id"], name: "IX_menu_category_products_menu_category_id", using: :btree
  add_index "menu_category_products", ["product_id"], name: "IX_menu_category_products_product_id", using: :btree

  create_table "orders", force: :cascade do |t|
    t.integer  "customer_id",   null: false
    t.integer  "shop_id",       null: false
    t.jsonb    "order_details"
    t.datetime "placed_at",     null: false
    t.datetime "in_queue_at",   null: false
    t.datetime "making_at",     null: false
    t.datetime "made_at",       null: false
    t.datetime "cancelled_at",  null: false
    t.datetime "collected_at",  null: false
    t.datetime "fail_at",       null: false
    t.text     "fail_reason"
  end

  add_index "orders", ["customer_id"], name: "IX_orders_customer_id", using: :btree
  add_index "orders", ["shop_id"], name: "IX_orders_shop_id", using: :btree

  create_table "product_variations", force: :cascade do |t|
    t.integer "product_id",        null: false
    t.integer "item_variation_id", null: false
    t.boolean "active",            null: false
    t.text    "title"
    t.float   "price_offset",      null: false
  end

  add_index "product_variations", ["item_variation_id"], name: "IX_product_variations_item_variation_id", using: :btree
  add_index "product_variations", ["product_id"], name: "IX_product_variations_product_id", using: :btree

  create_table "products", force: :cascade do |t|
    t.integer "shop_id", null: false
    t.text    "title"
    t.float   "price",   null: false
  end

  add_index "products", ["shop_id"], name: "IX_products_shop_id", using: :btree

  create_table "shops", force: :cascade do |t|
    t.integer "app_user_id", null: false
    t.text    "name"
    t.text    "address"
    t.float   "longitude",   null: false
    t.float   "latitude",    null: false
  end

  add_index "shops", ["app_user_id"], name: "IX_shops_app_user_id", using: :btree

  create_table "staffs", force: :cascade do |t|
    t.integer "shop_id", null: false
    t.integer "user_id", null: false
    t.text    "type"
  end

  add_index "staffs", ["shop_id"], name: "IX_staffs_shop_id", using: :btree
  add_index "staffs", ["user_id"], name: "IX_staffs_user_id", using: :btree

  add_foreign_key "app_users", "asp_net_users", column: "user_id", name: "fk_app_users_asp_net_users_user_id", on_delete: :restrict
  add_foreign_key "asp_net_role_claims", "asp_net_roles", column: "role_id", name: "fk_asp_net_role_claims_asp_net_roles_role_id", on_delete: :cascade
  add_foreign_key "asp_net_user_claims", "asp_net_users", column: "user_id", name: "fk_asp_net_user_claims_asp_net_users_user_id", on_delete: :cascade
  add_foreign_key "asp_net_user_logins", "asp_net_users", column: "user_id", name: "fk_asp_net_user_logins_asp_net_users_user_id", on_delete: :cascade
  add_foreign_key "asp_net_user_roles", "asp_net_roles", column: "role_id", name: "fk_asp_net_user_roles_asp_net_roles_role_id", on_delete: :cascade
  add_foreign_key "asp_net_user_roles", "asp_net_users", column: "user_id", name: "fk_asp_net_user_roles_asp_net_users_user_id", on_delete: :cascade
  add_foreign_key "asp_net_user_tokens", "asp_net_users", column: "user_id", name: "fk_asp_net_user_tokens_asp_net_users_user_id", on_delete: :cascade
  add_foreign_key "customer_shops", "app_users", column: "customer_id", name: "fk_customer_shops_app_users_customer_id", on_delete: :cascade
  add_foreign_key "customer_shops", "shops", name: "fk_customer_shops_shops_shop_id", on_delete: :cascade
  add_foreign_key "favourite_orders", "app_users", column: "customer_id", name: "fk_favourite_orders_app_users_customer_id", on_delete: :restrict
  add_foreign_key "favourite_orders", "orders", name: "fk_favourite_orders_orders_order_id", on_delete: :restrict
  add_foreign_key "item_variations", "items", name: "fk_item_variations_items_item_id", on_delete: :cascade
  add_foreign_key "menu_categories", "shops", name: "fk_menu_categories_shops_shop_id", on_delete: :cascade
  add_foreign_key "menu_category_products", "menu_categories", name: "fk_menu_category_products_menu_categories_menu_category_id", on_delete: :cascade
  add_foreign_key "menu_category_products", "products", name: "fk_menu_category_products_products_product_id", on_delete: :cascade
  add_foreign_key "orders", "app_users", column: "customer_id", name: "fk_orders_app_users_customer_id", on_delete: :cascade
  add_foreign_key "orders", "shops", name: "fk_orders_shops_shop_id", on_delete: :cascade
  add_foreign_key "product_variations", "item_variations", name: "fk_product_variations_item_variations_item_variation_id", on_delete: :cascade
  add_foreign_key "product_variations", "products", name: "fk_product_variations_products_product_id", on_delete: :cascade
  add_foreign_key "products", "shops", name: "fk_products_shops_shop_id", on_delete: :cascade
  add_foreign_key "shops", "app_users", name: "fk_shops_app_users_app_user_id", on_delete: :cascade
  add_foreign_key "staffs", "app_users", column: "user_id", name: "fk_staffs_app_users_user_id", on_delete: :cascade
  add_foreign_key "staffs", "shops", name: "fk_staffs_shops_shop_id", on_delete: :cascade
end
