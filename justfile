# Install watchexec to use this task.
watch:
    watchexec swift run

# Available configurations are "debug" and "release".
build configuration="debug":
    swift build -c {{configuration}}

run:
    swift run

format:
    swift format -ri .

distribute:
    ./Distribution/create_app_bundle.sh
