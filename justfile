# © 2026 Konstantin Gredeskoul

set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

repo    := 'git@github.com:inquirex/inquirex-tty.git'
version := `grep VERSION lib/inquirex/tty/version.rb | awk '{print $3}' | tr -d '"' | tr -d '\n'`

[no-exit-message]
recipes:
    just --choose

install:
    bundle check || bundle install -j 12

# Run full test suite with coverage
test:
    bundle exec rspec --format documentation

# Run RuboCop linter
lint:
    bundle exec rubocop

# Auto-correct RuboCop offenses
format:
    bundle exec rubocop -A

# Run a flow interactively
run flow_file:
    bundle exec exe/inquirex run {{flow_file}}

# Validate a flow definition
validate flow_file:
    bundle exec exe/inquirex validate {{flow_file}}

# Export a flow as a Mermaid diagram (stdout)
graph flow_file:
    bundle exec exe/inquirex graph {{flow_file}}

# Validate all examples
examples:
    #!/usr/bin/env bash
    set -e
    for f in examples/*.rb; do
        echo "=== $f ==="
        bundle exec exe/inquirex validate "$f"
        echo ""
    done

# Run all tests then lint
ci: test lint

alias check-all := ci

clean:
    #!/usr/bin/env bash
    @find . -name .DS_Store -delete -print || true
    @rm -rf tmp/*


version:
    @echo "{{ version }}"

# Tag v{{ version }}, publish the GH release, & refresh the Homebrew tap.
release:
    git fetch --tags
    git tag -f "v{{ version }}"
    git push -f --tags
    gh release delete -y "v{{ version }}" --repo {{ repo }} 2>/dev/null || true
    gh release create "v{{ version }}" --generate-notes --repo {{ repo }}
