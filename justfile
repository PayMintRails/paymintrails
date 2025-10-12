alias b := build
alias c := check
alias t := test

log := "warn"

export JUST_LOG := log

[private]
default:
  @just --list

# BUILDING

# run `cargo build` on everything
[group: 'build']
build *ARGS="--workspace --all-targets":
  #!/usr/bin/env bash
  set -euo pipefail
  if [ ! -f Cargo.toml ]; then
    cd {{invocation_directory()}}
  fi
  cargo build {{ARGS}}

# CHECKING

# run `cargo check` on everything
[group: 'check']
check *ARGS="--workspace --all-targets":
  #!/usr/bin/env bash
  set -euo pipefail
  if [ ! -f Cargo.toml ]; then
    cd {{invocation_directory()}}
  fi
  cargo check {{ARGS}}

[group: 'check']
check-all:
  @nix flake check

# generate test coverage report
[group: 'check']
coverage:
	cargo llvm-cov nextest --workspace --all-features --no-tests=pass

# run code formatters
[group: 'check']
format:
  #!/usr/bin/env bash
  set -euo pipefail
  if [ ! -f Cargo.toml ]; then
    cd {{invocation_directory()}}
  fi
  cargo fmt --all
  nix fmt $(git ls-files | grep "\.nix$")
  taplo fmt

# run code formatters without applying changes
[group: 'check']
format-check:
  #!/usr/bin/env bash
  set -euo pipefail
  if [ ! -f Cargo.toml ]; then
    cd {{invocation_directory()}}
  fi
  cargo fmt --all --check
  taplo fmt --check

# run linter
[group: 'check']
lint:
  #!/usr/bin/env bash
  set -euo pipefail
  if [ ! -f Cargo.toml ]; then
    cd {{invocation_directory()}}
  fi
  nix build .#checks."$(nix eval --raw --impure --expr builtins.currentSystem)".workspace-clippy

# check spelling
[group: 'check']
typos:
  #!/usr/bin/env bash
  set -euo pipefail
  if [ ! -f Cargo.toml ]; then
    cd {{invocation_directory()}}
  fi
  typos

# TESTING

# run tests
[group: 'test']
test name="": build
  #!/usr/bin/env bash
  set -euo pipefail
  if [ ! -f Cargo.toml ]; then
    cd {{invocation_directory()}}
  fi
  cargo nextest run --workspace --no-fail-fast --config-file ./.cargo/nextest.toml {{name}}
