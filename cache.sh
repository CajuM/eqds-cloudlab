#!/bin/sh

TOP=$(dirname $(readlink -f $0))
FLAKE="${TOP}?submodules=1"
TS=$(date -Iseconds)

machine=$1

for pkg in $(nix search --json "${FLAKE}#${machine}" '^' | jq -r ". | keys[]" | sed 's/.*\.//g'); do
	nix build -o "${TOP}/.cache/${pkg}-${machine}-${TS}" "${FLAKE}#${machine}.${pkg}"
done
