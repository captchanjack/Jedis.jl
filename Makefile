.PHONY: test
test:
	@docker run --name redis -d -p 6379:6379 -e ALLOW_EMPTY_PASSWORD=yes bitnami/redis:6.2.3
	@julia -e "using Pkg; Pkg.test()"
	@docker stop redis
	@docker rm redis
	@docker image rm bitnami/redis:6.2.3