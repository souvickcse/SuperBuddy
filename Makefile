APP := SuperBuddy
CONF ?= Release

# New buddy/support helpers are automatically included in headless tools.
CORE_SOURCES := $(sort $(wildcard Sources/Support/*.swift Sources/Buddy/*.swift) Sources/Scene/World.swift Sources/Scene/Battle.swift)

.PHONY: all run build gen preview check check-all icon dist clean

all: run

gen:
	xcodegen generate

build: gen
	xcodebuild -project $(APP).xcodeproj -scheme $(APP) -configuration $(CONF) -derivedDataPath build build

run: build
	open build/Build/Products/$(CONF)/$(APP).app

# renders docs/preview.png: every animation, straight from the real rig
preview:
	mkdir -p .build .mcache docs
	swiftc -module-cache-path "$$PWD/.mcache" -o .build/preview $(CORE_SOURCES) Tools/preview.swift
	./.build/preview docs/preview.png

# headless physics/behaviour smoke test
check:
	mkdir -p .build .mcache
	swiftc -parse-as-library -module-cache-path "$$PWD/.mcache" -o .build/simcheck $(CORE_SOURCES) Tools/simcheck.swift
	./.build/simcheck

check-all: check
	./.build/simcheck --deadpool
	./.build/simcheck --batman
	./.build/simcheck --hulk

icon:
	./Tools/make_icon.sh

# shareable universal build -> dist/*.zip and dist/*.dmg
dist:
	./Tools/make_dist.sh

clean:
	rm -rf build .build .mcache dist $(APP).xcodeproj docs/preview.png
