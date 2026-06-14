GEM_NAME    = active_harness_pricing
GEM_VERSION = $(shell ruby -e "load 'active_harness_pricing.gemspec'; puts Gem::Specification.load('active_harness_pricing.gemspec').version")
GEM_FILE    = $(GEM_NAME)-$(GEM_VERSION).gem

build:
	gem build $(GEM_NAME).gemspec

pub:
	make build
	gem push $(GEM_FILE)
	make clean

push:
	make pub

public:
	make pub

clean:
	rm -rf *.gem

stats:
	@curl -s https://rubygems.org/api/v1/gems/$(GEM_NAME).json | \
	  ruby -rjson -e 'd=JSON.parse(ARGF.read); puts "version:    " + d["version"]; puts "downloads:  " + d["version_downloads"].to_s + " (this version)"; puts "total:      " + d["downloads"].to_s + " (all versions)"'

readme:
	git add -A && git commit -m "Readme" && git push origin master

changelog:
	git add -A && git commit -m "CHANGELOG updated" && git push origin master

release:
	@V=$$(ruby -e "load 'active_harness_pricing.gemspec'; puts Gem::Specification.load('active_harness_pricing.gemspec').version"); \
	git add -A && \
	git commit -m "v$$V" && \
	git tag "v$$V" && \
	git push origin master && \
	git push origin "v$$V"
	make pub

sync-version:
	@V=$$(ruby -e "load 'active_harness_pricing.gemspec'; puts Gem::Specification.load('active_harness_pricing.gemspec').version"); \
	ruby -i -e "src=ARGF.read; src.sub!(/VERSION\s*=\s*\"[^\"]+\"/, \"VERSION = \\\"$$V\\\"\"); print src" lib/active_harness_pricing.rb
	@echo "VERSION in lib/active_harness_pricing.rb updated"

up:
	@ruby -i -e ' \
	  src = ARGF.read; \
	  src.sub!(/spec\.version\s*=\s*"(\d+)\.(\d+)\.(\d+)"/) { \
	    "spec.version       = \"#{$$1}.#{$$2}.#{$$3.to_i + 1}\"" \
	  }; \
	  print src \
	' active_harness_pricing.gemspec
	@echo "version → $$(ruby -e "load 'active_harness_pricing.gemspec'; puts Gem::Specification.load('active_harness_pricing.gemspec').version")"
	make sync-version
	make release

up/minor:
	@ruby -i -e ' \
	  src = ARGF.read; \
	  src.sub!(/spec\.version\s*=\s*"(\d+)\.(\d+)\.(\d+)"/) { \
	    "spec.version       = \"#{$$1}.#{$$2.to_i + 1}.0\"" \
	  }; \
	  print src \
	' active_harness_pricing.gemspec
	@echo "version → $$(ruby -e "load 'active_harness_pricing.gemspec'; puts Gem::Specification.load('active_harness_pricing.gemspec').version")"
	make sync-version
	make release

up/major:
	@ruby -i -e ' \
	  src = ARGF.read; \
	  src.sub!(/spec\.version\s*=\s*"(\d+)\.(\d+)\.(\d+)"/) { \
	    "spec.version       = \"#{$$1.to_i + 1}.0.0\"" \
	  }; \
	  print src \
	' active_harness_pricing.gemspec
	@echo "version → $$(ruby -e "load 'active_harness_pricing.gemspec'; puts Gem::Specification.load('active_harness_pricing.gemspec').version")"
	make sync-version
	make release
