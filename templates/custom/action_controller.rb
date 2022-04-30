module ActionController
  class Base
    def self.require(require)
      add(:require, require)
    end
  end
end
