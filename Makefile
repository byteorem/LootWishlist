# LootWishlist Makefile

.PHONY: test lint all clean

# Default target
all: lint test

# Run CLI unit tests
test:
	@lua Tests/CLI/run.lua

# Run luacheck linter
lint:
	@luacheck .

# Run both (explicit)
check: lint test

# Help
help:
	@echo "Available targets:"
	@echo "  make test   - Run CLI unit tests"
	@echo "  make lint   - Run luacheck linter"
	@echo "  make all    - Run lint and test (default)"
	@echo "  make check  - Same as 'all'"
	@echo "  make help   - Show this help"
