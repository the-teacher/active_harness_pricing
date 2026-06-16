module ActiveHarness
  module Pricing
    # Converts any model identifier or display name to a canonical lookup key.
    #
    # Works on both raw provider model IDs and human-readable display names,
    # producing the same key for the same model regardless of source.
    #
    # Examples:
    #   Normalizer.to_key("Mistral Nemo")                                # => "mistral-nemo"
    #   Normalizer.to_key("mistralai/mistral-nemo")                      # => "mistral-nemo"
    #   Normalizer.to_key("GPT-4o")                                      # => "gpt-4o"
    #   Normalizer.to_key("gpt-4o")                                      # => "gpt-4o"
    #   Normalizer.to_key("claude-3-5-haiku-20241022")                   # => "claude-3-5-haiku"
    #   Normalizer.to_key("global.anthropic.claude-haiku-4-5-20251001-v1:0") # => "claude-haiku-4-5"
    #   Normalizer.to_key("models/gemini-2.5-flash")                     # => "gemini-2-5-flash"
    module Normalizer
      def self.to_key(str)
        s = str.to_s.downcase

        # Strip "author/" prefix  ("mistralai/mistral-nemo" → "mistral-nemo")
        s = s.split("/").last if s.include?("/")

        # Strip leading "word." segments  ("global.anthropic.claude-..." → "claude-...")
        s = s.sub(/\A[a-z]+\./, "") while s.match?(/\A[a-z]+\.[a-z]/)

        # Normalize all non-alphanumeric characters to hyphens
        s = s.gsub(/[^a-z0-9]/, "-")

        # Strip date suffixes and everything that follows
        s = s.gsub(/-\d{8}.*/, "")             # -YYYYMMDD...
        s = s.gsub(/-\d{4}-\d{2}-\d{2}.*/, "") # -YYYY-MM-DD...
        s = s.gsub(/-\d{2}-\d{2}$/, "")        # trailing -MM-DD (Gemini preview dates)

        # Strip version suffixes  ("-v2:0", "-v1-0")
        s = s.gsub(/-v\d+(-\d+)?$/, "")

        # Strip common qualifiers
        s = s.gsub(/-(latest|online|free|exp)$/, "")

        s.squeeze("-").gsub(/^-|-$/, "")
      end
    end
  end
end
