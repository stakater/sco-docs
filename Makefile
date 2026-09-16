# Local automation for the docs screenshots.
#
# The capture script comes from the shared repo. The ref is pinned, so a change
# there cannot change published screenshots without a commit here. makefiles/ is
# downloaded, and gitignored.
DOCS_SS_REF ?= v0.0.199
DOCS_SS_MK_URL ?= https://raw.githubusercontent.com/stakater/.github/$(DOCS_SS_REF)/.github/makefiles/docs-screenshots.mk
DOCS_SS_MK := makefiles/docs-screenshots.mk

.DEFAULT_GOAL := help
.PHONY: help screenshots screenshots-one screenshots-check clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

$(DOCS_SS_MK): ## Download the shared screenshot makefile (only if missing)
	@mkdir -p $(dir $@)
	@echo "Downloading $(DOCS_SS_MK_URL) -> $@"
	@curl -H 'Cache-Control: no-cache' -fsSL "$(DOCS_SS_MK_URL)" -o "$@" \
	  || { echo "ERROR: failed to download $(DOCS_SS_MK_URL)"; exit 1; }

# The build resolves {{ screenshot: ... }} itself (see screenshots/mkdocs_hook.py).
screenshots: $(DOCS_SS_MK) ## Capture live console screenshots into screenshots/captured/
	$(MAKE) -f $(DOCS_SS_MK) capture DOCS_SS_REF=$(DOCS_SS_REF)

screenshots-one: $(DOCS_SS_MK) ## Capture one flow: make screenshots-one FLOW=<name>
	$(MAKE) -f $(DOCS_SS_MK) capture-one FLOW=$(FLOW) DOCS_SS_REF=$(DOCS_SS_REF)

screenshots-check: $(DOCS_SS_MK) ## Read-only: check every {{ screenshot: ... }} has a captured image
	$(MAKE) -f $(DOCS_SS_MK) check

clean: ## Delete the downloaded makefile fragment and script
	rm -rf makefiles
