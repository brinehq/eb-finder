# The Xcode project is generated from "EB Finder/project.yml" by XcodeGen and is
# NOT committed. Run `make` after cloning, or after pulling project.yml changes.
#
# Install XcodeGen once:  brew install xcodegen

.PHONY: project open clean

project:
	cd "EB Finder" && xcodegen generate

open: project
	open "EB Finder/EB Finder.xcodeproj"

clean:
	rm -rf "EB Finder/EB Finder.xcodeproj"
