# Default recipe: list available commands
default:
    @just --list

# Format all code (Nix + Markdown)
fmt:
    treefmt

# Check formatting (Nix + Markdown)
fmt-check:
    treefmt --fail-on-change --no-cache

# Run dead-code lints over the Nix sources
lint:
    deadnix --fail .

# Evaluate every flake output
check:
    nix flake check

# Build and check this week's tarball without publishing it
dry-run:
    nix run .#publish -- --dry-run

# Run all CI checks locally
ci: fmt-check lint check
    @echo "All CI checks passed!"
