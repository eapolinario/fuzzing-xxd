.DEFAULT_GOAL := help

.PHONY: help hypothesis diff_fuzz test check-radamsa

help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

hypothesis: ## Run Hypothesis-based pytest
	uv run --with hypothesis --with pytest pytest -vvv diff_test_hypothesis.py

diff_fuzz: check-radamsa ## Run diff_fuzz script
	uv run diff_fuzz.py

test: hypothesis diff_fuzz ## Run both tests (hypothesis, then diff_fuzz)

check-radamsa: ## Ensure radamsa is installed and on PATH
	@command -v radamsa >/dev/null 2>&1 || { echo "Error: radamsa not found in PATH. Please install it (e.g., brew install radamsa, apt-get install radamsa)."; exit 1; }
