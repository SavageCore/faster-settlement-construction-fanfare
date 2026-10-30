# Faster Settlement Construction Fanfare
# Builds the plain-zip mod with the AMUMSS Linux port.
#
# What it does: when a settlement building finishes, the game plays a 10
# second reveal cutscene with a CONSTRUCTION COMPLETE banner and fireworks.
# This shortens that cutscene to 1 second.
#
# Every value this mod patches lives in src/patches.tsv. That table drives
# both the rendered script and the verify step, so a value can never be
# patched without also being checked.
#
# Usage:
#   make release      clean rebuild + verify + pack dist/ zip (default)
#   make verify       sanity-check the built outputs
#   make clean        remove build/ and dist/
#   make assets       regenerate the Nexus page images (header + gallery)
#
# Override the AMUMSS install location if needed:
#   make AMUMSS_HOME=/path/to/AMUMSS release
#
# Game-update playbook (see README.md):
#   1. fetch latest MBINCompiler into AMUMSS_HOME
#   2. re-derive the base in src/patches.tsv (see README.md)
#   3. bump VERSION below (the mod version, published on Nexus)
#   4. make release, import + deploy + test in game

AMUMSS_HOME ?= $(HOME)/AMUMSS
AMUMSS_LINUX ?= $(HOME)/Git/AMUMSS/linux

# The mod version, published as the version of the Nexus release. An
# unreleased build stays at 0.0.0; the first public release bumps this in a
# commit of its own. The version is deliberately not part of the mod name:
# the artifact is named after the mod alone (see ROOTZIP), because a mod
# manager names the installed mod after the archive file name and shows the
# version in a column of its own.
VERSION      := 0.0.0

MOD_SET      := Faster Settlement Construction Fanfare

SRC_TEMPLATE := src/fanfare.lua.in
SRC_TABLE    := src/patches.tsv

BUILD := build
DIST  := dist
STAMP := $(BUILD)/.built

RENDERED := $(BUILD)/mod.lua
EXPECTED := $(BUILD)/mod.expected.tsv

# clean runs before build runs before verify, so release must not be parallel.
.NOTPARALLEL:

.PHONY: all release render build verify rootzip clean assets

all: release

# Single canonical artifact: the mod folder zipped as-is (Amethyst default
# import, or drop the folder into GAMEDATA/MODS). A single-configuration
# mod ships a plain zip and nothing else.
ROOTZIP := $(DIST)/$(MOD_SET).zip

release: clean render build verify rootzip
	@echo "release: $(ROOTZIP) (version $(VERSION))"

render: $(SRC_TEMPLATE) $(SRC_TABLE) src/render_mod.py
	@mkdir -p "$(BUILD)"
	@python3 src/render_mod.py --template "$(SRC_TEMPLATE)" --table "$(SRC_TABLE)" \
		--out-script "$(RENDERED)" --out-expected "$(EXPECTED)"

build: render
	@test -d "$(AMUMSS_HOME)/MODBUILDER" || (echo "ERROR: no AMUMSS install at $(AMUMSS_HOME) (set AMUMSS_HOME=...)" >&2; exit 1)
	@test -x "$(AMUMSS_HOME)/MODBUILDER/MBINCompiler-linux" || (echo "ERROR: run $(AMUMSS_LINUX)/scripts/fetch_mbincompiler.sh with AMUMSS_HOME=$(AMUMSS_HOME) first" >&2; exit 1)
	@mkdir -p "$(BUILD)"
	@set -e; \
	if [ -d "$(AMUMSS_HOME)/ModScript" ]; then mv "$(AMUMSS_HOME)/ModScript" "$(AMUMSS_HOME)/ModScript.makebak"; trap 'rm -rf "$(AMUMSS_HOME)/ModScript"; mv "$(AMUMSS_HOME)/ModScript.makebak" "$(AMUMSS_HOME)/ModScript"' EXIT; fi; \
	mkdir -p "$(AMUMSS_HOME)/ModScript"; \
	cp "$(RENDERED)" "$(AMUMSS_HOME)/ModScript/mod.lua"; \
	rm -rf "$(AMUMSS_HOME)/CreatedMODS/$(MOD_SET)"; \
	AMUMSS_HOME="$(AMUMSS_HOME)" "$(AMUMSS_LINUX)/buildmod.sh" --run-pipeline; \
	rm -rf "$(AMUMSS_HOME)/ModScript"; \
	if [ -d "$(AMUMSS_HOME)/ModScript.makebak" ]; then mv "$(AMUMSS_HOME)/ModScript.makebak" "$(AMUMSS_HOME)/ModScript"; fi; \
	trap - EXIT
	@set -e; \
		rm -rf "$(BUILD)/$(MOD_SET)"; \
		mkdir -p "$(BUILD)/$(MOD_SET)"; \
		cp -a "$(AMUMSS_HOME)/CreatedMODS/$(MOD_SET)"/* "$(BUILD)/$(MOD_SET)/"; \
		cp "$(RENDERED)" "$(BUILD)/$(MOD_SET)/mod.lua"
	@touch "$(STAMP)"
	@echo "built: $(BUILD)/$(MOD_SET)"

verify: build
	@python3 src/verify_build.py --build "$(BUILD)" --mod-set "$(MOD_SET)"

rootzip: verify
	@rm -rf "$(BUILD)/rootzip" && mkdir -p "$(BUILD)/rootzip"
	@cp -a "$(BUILD)/$(MOD_SET)" "$(BUILD)/rootzip/"
	@rm -f "$(BUILD)/rootzip/$(MOD_SET)/AMUMSS_v"*.txt
	@mkdir -p "$(DIST)" && rm -f "$(ROOTZIP)" && cd "$(BUILD)/rootzip" && zip -qr "$(shell pwd)/$(ROOTZIP)" "$(MOD_SET)"
	@echo "packed: $(ROOTZIP) (version $(VERSION))"
	@unzip -l "$(ROOTZIP)" | tail -4

# Nexus page images from the source screenshot. The generated images are
# build artifacts and are not tracked; the source screenshot and the
# typeface are.
assets: assets/src/gallery-fanfare.jpg assets/generate.py
	python3 assets/generate.py

clean:
	rm -rf "$(BUILD)" "$(DIST)"
