# frozen_string_literal: true

module Docsterra
  module Model
    class Relationship
      attr_reader :source, :target, :type, :detail

      def initialize(source:, target:, type:, detail:)
        @source = source
        @target = target
        @type = type
        @detail = detail
      end

      def key
        [source_key, target_key, type, detail]
      end

      private

      def source_key
        if source.respond_to?(:identifier)
          source.identifier
        elsif source.respond_to?(:name)
          source.name
        else
          source.to_s
        end
      end

      def target_key
        if target.respond_to?(:identifier)
          target.identifier
        elsif target.respond_to?(:name)
          target.name
        else
          target.to_s
        end
      end
    end
  end
end
