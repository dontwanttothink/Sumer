#!/bin/zsh
find . -name "*.swift" -not -path "./.build/*" | entr -r swift run
