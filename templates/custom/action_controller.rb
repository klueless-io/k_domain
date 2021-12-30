module ActionController
  class Base
    def self.require(require)
      add(:require, require)
    end
    # def self.rescue_from(type)#, &block)
    #   # block_source = nil
    #   # block_source = lambda_source(block, 'default_scope') if block_given?

    #   add(:rescue_from, {
    #         type: type#,
    #         # block: block_source
    #       })
    # end
    # def self.helper_method(*names)
    #   add(:helper_method, {
    #         names: names
    #       })
    # end
    # def self.helper(name)
    #   add(:helper, {
    #         name: name
    #       })
    # end
    # def self.http_basic_authenticate_with(**opts)
    #   add(:http_basic_authenticate_with, {
    #         opts: opts
    #       })
    # end
    # def self.protect_from_forgery(**opts)
    #   add(:protect_from_forgery, {
    #         opts: opts
    #       })
    # end
  end
end
