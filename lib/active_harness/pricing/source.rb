require "json"

module ActiveHarness
  module Pricing
    # Reads a standardized pricing data file and looks up models by canonical key.
    # Data is loaded lazily on first access and reloaded automatically after CACHE_TTL.
    #
    # Data file format (JSON hash):
    #   {
    #     "mistral-nemo": {
    #       "name":                "Mistral Nemo",
    #       "input_per_1m":        0.02,
    #       "output_per_1m":       0.03,
    #       "context_window":      131072,
    #       "tokens_per_second":   56.87,   # optional
    #       "time_to_first_token": 0.99     # optional
    #     }
    #   }
    #
    # Usage:
    #   src = Source.new("data/pricepertoken.json", :pricepertoken)
    #   src.find("mistral-nemo")           # exact
    #   src.find("mistral-nemo-instruct")  # prefix fallback
    class Source
      CACHE_TTL = 86_400  # 24 hours

      PricingData = Struct.new(
        :key,
        :name,
        :source,
        :input_per_1m,
        :output_per_1m,
        :context_window,
        :tokens_per_second,
        :time_to_first_token,
        keyword_init: true
      ) do
        def inspect
          "#<PricingData source=#{source} key=#{key.inspect}" \
            " in=$#{input_per_1m}/M out=$#{output_per_1m}/M>"
        end
      end

      def initialize(data_file, source_name)
        @data_file   = data_file
        @source_name = source_name.to_sym
      end

      # Finds a model by canonical key.
      # Falls back to prefix match when exact key is not found
      # (e.g. "mistral-nemo-instruct-2407" → finds "mistral-nemo").
      def find(canonical_key)
        key = canonical_key.to_s

        raw = data[key]
        return build(key, raw) if raw

        # prefix fallback: find the longest stored key that is a prefix of the lookup key
        match_key, match_raw = data
          .select { |k, _| key.start_with?(k) && k.length >= 5 }
          .max_by { |k, _| k.length }

        build(match_key, match_raw) if match_raw
      end

      def all
        data.map { |key, raw| build(key, raw) }
      end

      def reload!
        @data      = nil
        @loaded_at = nil
      end

      private

      def data
        expire_if_stale
        @data ||= load_data
      end

      def expire_if_stale
        return unless @loaded_at && (Time.now - @loaded_at) >= CACHE_TTL
        @data      = nil
        @loaded_at = nil
      end

      def load_data
        @loaded_at = Time.now
        return {} unless File.exist?(@data_file)
        JSON.parse(File.read(@data_file))
      rescue StandardError
        {}
      end

      def build(key, raw)
        PricingData.new(
          key:                 key,
          name:                raw["name"],
          source:              @source_name,
          input_per_1m:        raw["input_per_1m"],
          output_per_1m:       raw["output_per_1m"],
          context_window:      raw["context_window"],
          tokens_per_second:   raw["tokens_per_second"],
          time_to_first_token: raw["time_to_first_token"]
        )
      end
    end
  end
end
