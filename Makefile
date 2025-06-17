
.PHONY: build run

build:
	docker bake

run:
	docker compose up --remove-orphans --watch work