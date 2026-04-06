APP = SnapRatio

build:
	@bash build.sh

run: build
	@pkill -x $(APP) 2>/dev/null || true
	@sleep 0.3
	@open $(APP).app

.PHONY: build run
