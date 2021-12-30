# Implement data capture methods for the Rails Action Controller class
#
# This Shim will intercept any DSL methods and convert their paramaters into a data hash
module ActionController
  extend RubyCodeExtractor::AttachClassInfo

  class Base
    extend RubyCodeExtractor::BehaviourAccessors

    def self.singleton_class
      Class.new do
        def send(*_p, **_o); end
      end.new
    end

    def self.class_info
      return ActionController.class_info if ActionController.class_info

      ActionController.class_info = {
        class_name: name
      }
    end

    def self.after_action(name, **opts)
      add(:after_action, {
            name: name,
            opts: opts
          })
    end

    def self.around_action(name, **opts)
      add(:around_action, {
            name: name,
            opts: opts
          })
    end

    def self.before_action(name, **opts)
      add(:before_action, {
            name: name,
            opts: opts
          })
    end

    def self.prepend_before_action(name, **opts)
      add(:prepend_before_action, {
            name: name,
            opts: opts
          })
    end

    def self.skip_before_action(name, **opts)
      add(:skip_before_action, {
            name: name,
            opts: opts
          })
    end

    def self.before_filter(name, **opts)
      add(:before_filter, {
            name: name,
            opts: opts
          })
    end
    
    def self.skip_before_filter(name, **opts)
      add(:skip_before_filter, {
            name: name,
            opts: opts
          })
    end

    def self.layout(name, **opts)
      set(:layout, {
            name: name,
            opts: opts
          })
    end

    def self.rescue_from(type)#, &block)
      # block_source = nil
      # block_source = lambda_source(block, 'default_scope') if block_given?

      add(:rescue_from, {
            type: type#,
            # block: block_source
          })
    end

    # TODO: https://apidock.com/rails/ActionController/Helpers/ClassMethods/helper_method (MAYBE DEPRECATED?)
    def self.helper_method(*names)
      add(:helper_method, {
            names: names
          })
    end

    # TODO: https://apidock.com/rails/ActionController/Helpers/ClassMethods/helper
    def self.helper(name)
      add(:helper, {
            name: name
          })
    end

    def self.http_basic_authenticate_with(**opts)
      set(:http_basic_authenticate_with, {
            opts: opts
          })
    end

    def self.protect_from_forgery(**opts)
      set(:protect_from_forgery, {
            opts: opts
          })
    end
  end
end

# after_action
# after_filter
# append_after_action
# append_after_filter
# append_around_action
# append_around_filter
# append_before_action
# append_before_filter
# append_view_path
# around_action
# around_filter
# before_action
# before_filter
# controller_name
# controller_path
# helper
# helper_attr
# helper_method
# helpers
# helpers_path
# hide_action
# http_basic_authenticate_with
# layout
# prepend_after_action
# prepend_after_filter
# prepend_around_action
# prepend_around_filter
# prepend_before_action
# prepend_before_filter
# prepend_view_path
# protect_from_forgery
# protected_instance_variables
# rescue_from
# reset_callbacks
# skip_action_callback
# skip_after_action
# skip_after_filter
# skip_around_action
# skip_around_filter
# skip_before_action
# skip_before_filter
# skip_callback
# skip_filter

# METHOD LIST - Just from running self.class.methods - Object.methods on a running controller
# action
# action_methods
# add_flash_types
# after_action
# after_filter
# all_helpers_from_path
# allow_forgery_protection
# allow_forgery_protection=
# append_after_action
# append_after_filter
# append_around_action
# append_around_filter
# append_before_action
# append_before_filter
# append_view_path
# around_action
# around_filter
# asset_host
# asset_host=
# assets_dir
# assets_dir=
# before_action
# before_filter
# cache_store
# cache_store=
# call
# clear_action_methods!
# clear_helpers
# clear_respond_to
# config
# config_accessor
# configure
# controller_name
# controller_path
# default_asset_host_protocol
# default_asset_host_protocol=
# default_static_extension
# default_static_extension=
# default_url_options
# default_url_options=
# default_url_options?
# define_callbacks
# devise_group
# direct_descendants
# etag
# etag_with_template_digest
# etag_with_template_digest=
# etag_with_template_digest?
# etaggers
# etaggers=
# etaggers?
# force_ssl
# forgery_protection_strategy
# forgery_protection_strategy=
# get_callbacks
# helper
# helper_attr
# helper_method
# helpers
# helpers_path
# helpers_path=
# helpers_path?
# hidden_actions
# hidden_actions=
# hidden_actions?
# hide_action
# http_basic_authenticate_with
# include_all_helpers
# include_all_helpers=
# include_all_helpers?
# inherited
# internal_methods
# javascripts_dir
# javascripts_dir=
# layout
# log_process_action
# log_warning_on_csrf_failure
# log_warning_on_csrf_failure=
# logger
# logger=
# method_added
# middleware
# middleware_stack
# middleware_stack=
# middleware_stack?
# mimes_for_respond_to
# mimes_for_respond_to=
# mimes_for_respond_to?
# modules_for_helpers
# normalize_callback_params
# perform_caching
# perform_caching=
# prepend_after_action
# prepend_after_filter
# prepend_around_action
# prepend_around_filter
# prepend_before_action
# prepend_before_filter
# prepend_view_path
# protect_from_forgery
# protected_instance_variables
# relative_url_root
# relative_url_root=
# request_forgery_protection_token
# request_forgery_protection_token=
# rescue_from
# rescue_handlers
# rescue_handlers=
# rescue_handlers?
# reset_callbacks
# respond_to
# responder
# responder=
# responder?
# responders
# set_callback
# set_callbacks
# skip_action_callback
# skip_after_action
# skip_after_filter
# skip_around_action
# skip_around_filter
# skip_before_action
# skip_before_filter
# skip_callback
# skip_filter
# stylesheets_dir
# stylesheets_dir=
# supports_path?
# use
# use_renderer
# use_renderers
# view_cache_dependency
# view_context_class
# view_paths
# view_paths=
# visible_action?
# without_modules
# wrap_parameters