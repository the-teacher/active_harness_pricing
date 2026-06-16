require "json"

module ActiveHarness
  module Pricing
    # Pricing data from pricepertoken.com — bundled as data/pricepertoken.json,
    # refreshed daily via GitHub Actions.
    #
    # Usage:
    #   Pricing::PricePerToken.all
    #   Pricing::PricePerToken.find("anthropic-claude-sonnet-4.6")
    #   Pricing::PricePerToken.for_author("anthropic")
    module PricePerToken
      DATA_FILE = File.expand_path("../../../data/pricepertoken.json", __dir__)

      class << self
        def all
          registry.map { |raw| build_price(raw) }.compact
        end

        def find(slug)
          raw = registry.find { |m| m[:slug] == slug.to_s }
          raw ? build_price(raw) : nil
        end

        def for_author(name)
          registry
            .select { |m| m[:author_name].to_s.downcase == name.to_s.downcase }
            .map { |m| build_price(m) }
            .compact
        end

        def authors
          registry.map { |m| m[:author_name] }.uniq.sort
        end

        def reload!
          @registry = nil
        end

        def data_file
          DATA_FILE
        end

        private

        def registry
          @registry ||= load_registry
        end

        def load_registry
          return [] unless File.exist?(DATA_FILE)
          data = JSON.parse(File.read(DATA_FILE), symbolize_names: true)
          data.is_a?(Array) ? data : []
        rescue StandardError
          []
        end

        def build_price(raw)
          Pricing::ModelPrice.new(
            id:                            raw[:slug],
            name:                          raw[:model_name],
            provider:                      "pricepertoken",
            input_per_million:             raw[:input_per_1m],
            output_per_million:            raw[:output_per_1m],
            cache_read_input_per_million:  nil,
            cache_write_input_per_million: nil,
            context_window:                raw[:context_length],
            max_output_tokens:             nil,
            input_modalities:              raw[:supports_vision] ? %w[text image] : %w[text],
            output_modalities:             %w[text]
          )
        end
      end
    end
  end
end
