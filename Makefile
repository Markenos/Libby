.PHONY: project build run selftest clean

project:
	xcodegen generate -q

build: project
	xcodebuild -project Libby.xcodeproj -scheme Libby -configuration Debug -derivedDataPath build/dd build | grep -E "error|BUILD"

run: build
	-pkill -x Libby
	open build/dd/Build/Products/Debug/Libby.app

selftest: build
	build/dd/Build/Products/Debug/Libby.app/Contents/MacOS/Libby --selftest

clean:
	rm -rf build Libby.xcodeproj
