# List available recipes
default:
	@just --list --justfile "{{ justfile() }}"

pytest *args:
	uv run python -m pytest {{ args }}

test test_path *args:
	#!/usr/bin/env bash
	test_path="{{ test_path }}"
	if [[ -a "code/$test_path" ]]; then
		just pytest {{ args }} "code/$test_path"
	else
		just pytest "$test_path" {{ args }}
	fi
