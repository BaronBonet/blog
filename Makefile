guard-%:
	@ if [ "${${*}}" = "" ]; then \
        echo "Variable $* not set"; \
        exit 1; \
    fi

.PHONY: dev
dev:
	@cd src && hugo server

# Needed since cloudfront doesn't know how to handle hugo's pretty urls
.PHONY: create-edge-function
create-edge-function:
	@cd infra/lambda_edge_rewrite && zip -rj lambda_edge_rewrite.zip lambda_edge_rewrite.py

.PHONY: to-cdn
to-cdn: guard-fn
	@pngpaste /tmp/$(fn)
	@aws s3 cp /tmp/$(fn) s3://ericcbonet-blog-cdn/$(fn)
	@rm /tmp/$(fn)
	@echo "https://cdn.ericcbonet.com/$(fn)" | pbcopy
	@echo "Uploaded to cdn and copied url to clipboard"

