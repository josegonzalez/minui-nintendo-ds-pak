TAG ?= latest
PAK_NAME := $(shell jq -r .label config.json)

PLATFORMS := tg5040

clean:
	true

build:
	true

release: build
	mkdir -p dist
	git archive --format=zip --output "dist/$(PAK_NAME).pak.zip" HEAD
	while IFS= read -r file; do zip -r "dist/$(PAK_NAME).pak.zip" "$$file"; done < .gitarchiveinclude
	ls -lah dist