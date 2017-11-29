.PHONY: lint

lint:
	@luacheck -q ./lib/resty
