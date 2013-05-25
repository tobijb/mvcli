require "map"
require "active_support/concern"
require "active_support/dependencies"

module MVCLI
  module Provisioning
    extend ActiveSupport::Concern
    UnsatisfiedRequirement = Class.new StandardError
    MissingScope = Class.new StandardError

    module ClassMethods
      def requires(*deps)
        deps.each do |dep|
          self.send(:define_method, dep) {Scope[dep]}
        end
      end
    end

    class Scope
      def initialize(provisioner)
        @provisioner = provisioner
      end

      def [](name)
        @provisioner[name]
      end

      def evaluate
        old = self.class.current
        self.class.current = self
        yield
      ensure
        self.class.current = old
      end

      def self.current
        Thread.current[self.class.name]
      end

      def self.current!
        current or fail MissingScope, "attempting to access scope, but none is active!"
      end

      def self.current=(scope)
        Thread.current[self.class.name] = scope
      end

      def self.[](name)
        current![name] or fail UnsatisfiedRequirement, "'#{name}' is required, but can't find it"
      end
    end

    class Provisioner
      def [](name)
        provider = "#{name.capitalize}Provider".constantize.new
        provider.value
      end
    end

    class Middleware
      def call(command)
        Scope.new(Provisioner.new).evaluate do
          yield command
        end
      end
    end
    ::Object.send :include, self
  end
end
