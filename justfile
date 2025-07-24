watch:
    find . -name "*.swift" -not -path "./.build/*" | entr -r swift run

build:
    swift build

run:
    swift run
