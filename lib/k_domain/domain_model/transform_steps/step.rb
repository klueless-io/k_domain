# frozen_string_literal: true

module KDomain
  module DomainModel
    class Step
      attr_reader :domain_data
      attr_reader :opts
      attr_reader :valid
      alias :valid? :valid
    
      def initialize(domain_data, opts)
        # Useful for debugging
        # log.info "Initialize #{self.class.name}"
    
        @domain_data  = domain_data
        @opts         = opts
        @valid        = true
      end
    
      def call
      end
    
      def self.run(domain_data, opts)
        step = new(domain_data, opts)
        step.call
        step
      end
    
      def guard(message)
        log.error message
        @valid = false
      end

      def database=(value)
        domain_data[:database] = value
      end

      def database
        guard('database is missing') if domain_data[:database].nil?
  
        domain_data[:database]
      end
    end
  end
end