# inquirex-tty development tasks

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
    bundle exec exe/inquirex-tty run {{flow_file}}

# Validate a flow definition
validate flow_file:
    bundle exec exe/inquirex-tty validate {{flow_file}}

# Export a flow as a Mermaid diagram (stdout)
graph flow_file:
    bundle exec exe/inquirex-tty graph {{flow_file}}

# Validate all examples
examples:
    #!/usr/bin/env bash
    set -e
    for f in examples/*.rb; do
        echo "=== $f ==="
        bundle exec exe/inquirex-tty validate "$f"
        echo ""
    done

# Run all tests then lint
ci: test lint
