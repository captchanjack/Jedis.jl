.PHONY: test
test:
	@docker-compose -f docker/docker-compose.yml up -d
	@julia -e "using Pkg; Pkg.test()"
	@docker-compose -f docker/docker-compose.yml down --remove-orphans
	@docker image rm bitnami/redis:6.2.3