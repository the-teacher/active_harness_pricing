module ActiveHarness
  module Pricing
    # Queries all pricing sources for a given model and calculates costs.
    #
    # All cost methods accept either a request/result object OR explicit keyword args:
    #
    #   PriceResolver.max_cost(result)          # from ActiveHarness request result
    #   PriceResolver.max_cost(request)         # from ActiveHarness request instance
    #   PriceResolver.max_cost(model_id: "gpt-4o", tokens_input: 1000, tokens_output: 500)
    #
    # Resolved keys are cached in memory (TTL: 24h) — in production only a handful
    # of models are used, so the first lookup pays the search cost and every
    # subsequent call returns instantly from cache.
    module PriceResolver
      DATA_DIR  = File.expand_path("../../../data", __dir__)
      CACHE_TTL = 86_400  # 24 hours

      SOURCES = {
        pricepertoken: Source.new(File.join(DATA_DIR, "pricepertoken.json"), :pricepertoken),
        modelsdev:     Source.new(File.join(DATA_DIR, "modelsdev.json"),     :modelsdev),
        openrouter:    Source.new(File.join(DATA_DIR, "openrouter.json"),    :openrouter)
      }.freeze

      class << self
        # Returns { source_name => PricingData } for every source that has this model.
        # Result is cached by canonical key for CACHE_TTL seconds.
        def resolve(model_id)
          key = Normalizer.to_key(model_id)

          cached = resolve_cache[key]
          return cached unless cached.nil?

          result = SOURCES.each_with_object({}) do |(name, source), h|
            hit = source.find(key)
            h[name] = hit if hit&.input_per_1m && hit&.output_per_1m
          end

          resolve_cache[key] = result
          result
        end

        # Returns { source_name => Float (USD) } sorted from highest to lowest cost.
        # Accepts a result/request object or keyword args.
        def costs(subject = nil, model_id: nil, tokens_input: 0, tokens_output: 0)
          args = extract_args(subject, model_id: model_id, tokens_input: tokens_input, tokens_output: tokens_output)
          tokens_in  = args[:tokens_input].to_i
          tokens_out = args[:tokens_output].to_i
          raw = resolve(args[:model_id]).transform_values do |p|
            round_cost(
              (tokens_in  * p.input_per_1m  / 1_000_000.0) +
              (tokens_out * p.output_per_1m / 1_000_000.0)
            )
          end
          raw.sort_by { |_, v| -v }.to_h
        end

        # Returns the highest cost estimate across all sources (conservative upper bound).
        # Accepts a result/request object or keyword args.
        # Returns nil when no pricing data found.
        # Returns { cost: Float, source: Symbol, all: Hash } otherwise.
        def max_cost(subject = nil, model_id: nil, tokens_input: 0, tokens_output: 0, provider_cost: nil)
          args = extract_args(subject, model_id: model_id, tokens_input: tokens_input,
                                       tokens_output: tokens_output, provider_cost: provider_cost)

          return provider_result(args[:provider_cost], args[:model_id]) if args[:provider_cost].to_f > 0

          all = costs(model_id: args[:model_id], tokens_input: args[:tokens_input], tokens_output: args[:tokens_output])
          return nil if all.empty?

          src, cost = all.max_by { |_, v| v }
          { cost: round_cost(cost), source: src, all: all }
        end

        # Returns the lowest cost estimate across all sources (optimistic lower bound).
        # Accepts a result/request object or keyword args.
        # Returns nil when no pricing data found.
        # Returns { cost: Float, source: Symbol, all: Hash } otherwise.
        def min_cost(subject = nil, model_id: nil, tokens_input: 0, tokens_output: 0, provider_cost: nil)
          args = extract_args(subject, model_id: model_id, tokens_input: tokens_input,
                                       tokens_output: tokens_output, provider_cost: provider_cost)

          return provider_result(args[:provider_cost], args[:model_id]) if args[:provider_cost].to_f > 0

          all = costs(model_id: args[:model_id], tokens_input: args[:tokens_input], tokens_output: args[:tokens_output])
          return nil if all.empty?

          src, cost = all.min_by { |_, v| v }
          { cost: cost, source: src, all: all }
        end

        # Clears the resolve cache. Useful in tests or after manually refreshing data files.
        def clear_cache!
          @resolve_cache  = nil
          @cache_built_at = nil
        end

        private

        # Normalizes arguments from either a result/request object or explicit keyword args.
        # A request is any object that responds to :result (ActiveHarness request instance).
        # A result is any object with .model.name and .usage.tokens.{input,output}.
        def extract_args(subject, model_id: nil, tokens_input: 0, tokens_output: 0, provider_cost: nil)
          return { model_id: model_id, tokens_input: tokens_input,
                   tokens_output: tokens_output, provider_cost: provider_cost } if subject.nil?

          result = subject.respond_to?(:result) ? subject.result : subject

          {
            model_id:      result.model&.name.to_s,
            tokens_input:  result.usage&.tokens&.input.to_i,
            tokens_output: result.usage&.tokens&.output.to_i,
            provider_cost: result.usage&.cost&.total
          }
        end

        # Cache hash, reset automatically after CACHE_TTL.
        def resolve_cache
          if @cache_built_at.nil? || (Time.now - @cache_built_at) >= CACHE_TTL
            @resolve_cache  = {}
            @cache_built_at = Time.now
          end
          @resolve_cache
        end

        def provider_result(cost, model_id)
          c = round_cost(cost.to_f)
          { cost: c, source: :provider, all: { provider: c } }
        end

        # Rounds a cost value to eliminate float representation noise.
        # Adapts precision to magnitude: $0.01 → 6dp, $0.0001 → 8dp, etc.
        def round_cost(value)
          return 0.0 if value == 0
          magnitude = value.abs
          decimals  = if    magnitude >= 0.1   then 6
                      elsif magnitude >= 0.001 then 7
                      else                          8
                      end
          value.round(decimals)
        end
      end
    end
  end
end
