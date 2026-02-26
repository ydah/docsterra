# frozen_string_literal: true

module Terradoc
  module Model
    class Project
      Entry = Struct.new(:block, :file, keyword_init: true)

      attr_reader :name, :path, :parsed_files, :shared
      attr_accessor :resources, :data_sources, :variables, :outputs, :modules, :locals,
                    :providers, :terraform_blocks, :network, :security_report, :cost_items

      def initialize(name:, path:, parsed_files:, shared: false)
        @name = name
        @path = path
        @parsed_files = parsed_files
        @shared = shared

        @resources = []
        @data_sources = []
        @variables = []
        @outputs = []
        @modules = []
        @locals = []
        @providers = []
        @terraform_blocks = []
        @network = Model::Network.new
        @security_report = nil
        @cost_items = []

        extract_blocks
      end

      def shared?
        !!@shared
      end

      def resource_blocks
        @resource_blocks ||= []
      end

      def data_blocks
        @data_blocks ||= []
      end

      def all_resource_like
        resources + data_sources
      end

      def resources_by_identifier
        resources.each_with_object({}) { |resource, index| index[resource.identifier] = resource }
      end

      def reindex!
        @variables = []
        @outputs = []
        @modules = []
        @locals = []
        @providers = []
        @terraform_blocks = []
        extract_blocks
        self
      end

      private

      def extract_blocks
        @resource_blocks = []
        @data_blocks = []

        parsed_files.each do |file, ast|
          next unless ast.respond_to?(:blocks)

          ast.blocks.each do |block|
            entry = Entry.new(block: block, file: file)
            case block.type
            when "resource"
              @resource_blocks << entry
            when "data"
              @data_blocks << entry
            when "variable"
              @variables << entry
            when "output"
              @outputs << entry
            when "module"
              @modules << entry
            when "locals"
              @locals << entry
            when "provider"
              @providers << entry
            when "terraform"
              @terraform_blocks << entry
            end
          end
        end
      end
    end
  end
end
