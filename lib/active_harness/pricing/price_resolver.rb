module ActiveHarness
  module Pricing
    # Queries all pricing sources for a given model and calculates costs.
    #
    # Usage:
    #   # Look up pricing from all sources
    #   PriceResolver.resolve("mistralai/mistral-nemo")
    #   # => { pricepertoken: <PricingData ...>, modelsdev: <PricingData ...> }
    #
    #   # Calculate cost from all sources, pick the most conservative (highest)
    #   PriceResolver.best_cost(
    #     model_id:      "mistralai/mistral-nemo",
    #     tokens_input:  10_000,
    #     tokens_output: 2_000
    #   )
    #   # => { cost: 0.00026, source: :pricepertoken, all: { pricepertoken: 0.00026, modelsdev: 0.00025 } }
    module PriceResolver
      DATA_DIR = File.expand_path("../../../data", __dir__)

      SOURCES = {
        pricepertoken: Source.new(File.join(DATA_DIR, "pricepertoken.json"), :pricepertoken),
        modelsdev:     Source.new(File.join(DATA_DIR, "modelsdev.json"),     :modelsdev),
        openrouter:    Source.new(File.join(DATA_DIR, "openrouter.json"),    :openrouter)
      }.freeze

      class << self
        # Returns { source_name => PricingData } for every source that has this model.
        def resolve(model_id)
          key = Normalizer.to_key(model_id)
          SOURCES.each_with_object({}) do |(name, source), h|
            hit = source.find(key)
            h[name] = hit if hit&.input_per_1m && hit&.output_per_1m
          end
        end

        # Returns { source_name => Float (USD) } — cost per source.
        def costs(model_id:, tokens_input: 0, tokens_output: 0)
          pricing = resolve(model_id)
          tokens_in  = tokens_input.to_i
          tokens_out = tokens_output.to_i
          pricing.transform_values do |p|
            (tokens_in  * p.input_per_1m  / 1_000_000.0) +
            (tokens_out * p.output_per_1m / 1_000_000.0)
          end
        end

        # Returns the most conservative (highest) cost estimate across all sources.
        # This is the safe default — if sources disagree, assume the higher cost.
        #
        # Returns nil when no pricing data found.
        # Returns { cost: Float, source: Symbol, all: Hash } otherwise.
        def best_cost(model_id:, tokens_input: 0, tokens_output: 0, provider_cost: nil)
          # Provider-reported cost is always authoritative when available
          if provider_cost && provider_cost.to_f > 0
            return { cost: provider_cost.to_f, source: :provider, all: { provider: provider_cost.to_f } }
          end

          all = costs(model_id: model_id, tokens_input: tokens_input, tokens_output: tokens_output)
          return nil if all.empty?

          best_source, best_cost = all.max_by { |_, v| v }
          { cost: best_cost, source: best_source, all: all }
        end
      end
    end
  end
end
