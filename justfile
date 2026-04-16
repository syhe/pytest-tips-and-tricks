# List available recipes
default:
    @just --list --justfile "{{ justfile() }}"

pytest *args:
    uv run python -m pytest {{ args }}
