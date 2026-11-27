.PHONY: build-all build-desktop build-mobile check-desktop test-mobile

MOBILE_TARGET ?= apk

build-all:
	./scripts/build-all.sh $(MOBILE_TARGET)

build-desktop:
	./scripts/build-desktop.sh

check-desktop:
	./scripts/build-desktop.sh --check-only

build-mobile:
	./scripts/build-mobile.sh $(MOBILE_TARGET)

test-mobile:
	cd mobile-client && flutter pub get && flutter analyze && flutter test
