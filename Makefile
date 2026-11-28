.PHONY: build-all build-desktop build-mobile check-desktop test-mobile \
	install-desktop install-desktop-user install-desktop-system \
	uninstall-desktop-user uninstall-desktop-system

MOBILE_TARGET ?= apk

build-all:
	./scripts/build-all.sh $(MOBILE_TARGET)

build-desktop:
	./scripts/build-desktop.sh

check-desktop:
	./scripts/build-desktop.sh --check-only

install-desktop:
	./scripts/install-desktop.sh

install-desktop-user:
	./scripts/install-desktop.sh --user

install-desktop-system:
	./scripts/install-desktop.sh --system

uninstall-desktop-user:
	./scripts/install-desktop.sh --uninstall --user

uninstall-desktop-system:
	./scripts/install-desktop.sh --uninstall --system

build-mobile:
	./scripts/build-mobile.sh $(MOBILE_TARGET)

test-mobile:
	cd mobile-client && flutter pub get && flutter analyze && flutter test
