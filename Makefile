# LootWishlist Makefile

.PHONY: test test-staticdata lint all check data data-check clean help

# Default target
all: lint test test-staticdata

# Run CLI unit tests
test:
	@lua Tests/CLI/run.lua

# Run StaticData structure tests
test-staticdata:
	@lua Tests/CLI/run_staticdata.lua

# Run luacheck linter
lint:
	@luacheck .

# Run all checks (no network)
check: lint test test-staticdata

# Regenerate static data from Wago.tools
data:
	uv run tools/export_static_data.py

# Check static data freshness (requires network)
data-check:
	uv run tools/export_static_data.py --check

# Help
help:
	@echo "Available targets:"
	@echo "  make test            - Run CLI unit tests"
	@echo "  make test-staticdata - Run StaticData structure tests"
	@echo "  make lint            - Run luacheck linter"
	@echo "  make all             - Run lint, test, and test-staticdata (default)"
	@echo "  make check           - Same as 'all'"
	@echo "  make data            - Regenerate static data from Wago.tools"
	@echo "  make data-check      - Check static data freshness (requires network)"
	@echo "  make help            - Show this help"
