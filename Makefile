.PHONY: build app test smoke check-repo ci release-package npm-build npm-publish

build:
	swift build

app:
	./scripts/build-openara-app.sh debug

test:
	swift test

smoke:
	./scripts/run-tool-smoke-tests.sh

check-repo:
	./scripts/check-repo-hygiene.sh

ci:
	./scripts/ci.sh

release-package:
	./scripts/release-package.sh

npm-build:
	node ./scripts/npm/build-packages.mjs

npm-publish:
	node ./scripts/npm/publish-packages.mjs
