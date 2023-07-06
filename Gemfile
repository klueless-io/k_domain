# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in handlebars_helpers.gemspec
gemspec

# group :development do
#   # Currently conflicts with GitHub actions and so I remove it on push
#   # pry on steroids
#   gem 'jazz_fingers'
#   gem 'pry-coolline', github: 'owst/pry-coolline', branch: 'support_new_pry_config_api'
# end

group :development, :test do
  gem 'guard-bundler'
  gem 'guard-rspec'
  gem 'guard-rubocop'
  gem 'rake'
  gem 'rake-compiler', require: false
  gem 'rspec', '~> 3.0'
  gem 'rubocop'
  gem 'rubocop-rake', require: false
  gem 'rubocop-rspec', require: false
end

# If local dependency
if ENV.fetch('KLUE_LOCAL_GEMS', 'false').downcase == 'true'
  group :development, :test do
    puts 'Using Local GEMs'
    gem 'cmdlet'                  , path: '../cmdlet'
    gem 'k_log'                   , path: '../k_log'
    gem 'k_util'                  , path: '../k_util'
    gem 'peeky'                   , path: '../peeky'
  end
end
