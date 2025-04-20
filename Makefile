TAG ?= latest
PAK_NAME := $(shell jq -r .label config.json)

PLATFORMS := tg5040

MINUI_POWER_CONTROL_VERSION := 1.1.0

clean:
	rm -f bin/minui-power-control

build: bin/minui-power-control

bin/minui-power-control:
	mkdir -p bin
	curl -f -o bin/minui-power-control -sSL https://github.com/ben16w/minui-power-control/releases/download/$(MINUI_POWER_CONTROL_VERSION)/minui-power-control
	chmod +x bin/minui-power-control

release: build
	mkdir -p dist
	git archive --format=zip --output "dist/$(PAK_NAME).pak.zip" HEAD
	while IFS= read -r file; do zip -r "dist/$(PAK_NAME).pak.zip" "$$file"; done < .gitarchiveinclude
	ls -lah dist