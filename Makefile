.PHONY: run deploy build clean

BUNDLE   := web/balduin.zip
SOURCES  := balduin.exe sprites.bmp level001.bld level002.bld level003.bld level004.bld level005.bld
PORT     ?= 8765
PROJECT  := balduin

# Build the .jsdos/.zip bundle the web launcher extracts at runtime.
build: $(BUNDLE)

$(BUNDLE): $(SOURCES)
	@rm -rf web/_bundle
	@mkdir -p web/_bundle
	@cp balduin.exe web/_bundle/
	@cp sprites.bmp web/_bundle/SPRITES.BMP
	@cp level00?.bld web/_bundle/
	@printf '[cpu]\ncycles=fixed 26532\n' > web/_bundle/dosbox.conf
	@rm -f $@
	@cd web/_bundle && zip -qr ../$(notdir $@) . -x "*.DS_Store"
	@rm -rf web/_bundle
	@echo "built $@"

# Serve the web/ directory locally for development.
run: build
	@echo "→ http://localhost:$(PORT)/"
	cd web && python3 -m http.server $(PORT)

# Push the web/ directory to Cloudflare Pages.
deploy: build
	wrangler pages deploy web --project-name=$(PROJECT) --branch=main --commit-dirty=true

clean:
	rm -rf web/_bundle $(BUNDLE)
