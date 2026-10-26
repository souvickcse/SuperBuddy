APP := SuperBuddy
CONF ?= Release

.PHONY: all run build gen preview check icon dist clean

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
	swiftc -module-cache-path "$$PWD/.mcache" -o .build/preview Sources/Support/MathUtil.swift Sources/Support/TimingSettings.swift Sources/Buddy/Pose.swift Sources/Buddy/Motions.swift Sources/Buddy/Skin.swift Sources/Buddy/Rig.swift Sources/Support/Debug.swift Sources/Buddy/WebLine.swift Sources/Buddy/Effects.swift Sources/Buddy/Villain.swift Sources/Scene/World.swift Sources/Scene/Battle.swift Sources/Buddy/Buddy.swift Sources/Buddy/Batmobile.swift Sources/Buddy/BatSignal.swift Tools/preview.swift
	./.build/preview docs/preview.png

# headless physics/behaviour smoke test
check:
	mkdir -p .build .mcache
	swiftc -parse-as-library -module-cache-path "$$PWD/.mcache" -o .build/simcheck Sources/Support/MathUtil.swift Sources/Support/TimingSettings.swift Sources/Support/Debug.swift Sources/Buddy/Pose.swift Sources/Buddy/Motions.swift Sources/Buddy/Skin.swift Sources/Buddy/Rig.swift Sources/Buddy/WebLine.swift Sources/Buddy/Effects.swift Sources/Buddy/Villain.swift Sources/Scene/World.swift Sources/Scene/Battle.swift Sources/Buddy/Buddy.swift Sources/Buddy/Batmobile.swift Sources/Buddy/BatSignal.swift Tools/simcheck.swift
	./.build/simcheck

icon:
	./Tools/make_icon.sh

# shareable universal build -> dist/*.zip and dist/*.dmg
dist:
	./Tools/make_dist.sh

clean:
	rm -rf build .build .mcache dist $(APP).xcodeproj docs/preview.png
