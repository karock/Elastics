#!/bin/bash
#
# Writes Signing.local.xcconfig so Xcode signs Elastics and Elastics Preferences with
# a certificate from your keychain instead of the local (ad-hoc) signature.
#
#   scripts/configure-signing.sh            pick automatically: a "Developer ID
#                                           Application" certificate if you have one,
#                                           otherwise "Apple Development"
#   scripts/configure-signing.sh "text"     use the first identity whose name contains text
#   scripts/configure-signing.sh --reset    go back to the local (ad-hoc) signature
#
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG=Signing.local.xcconfig

if [ "${1:-}" = "--reset" ]; then
	rm -f "$CONFIG"
	echo "Removed $CONFIG; builds use the local (ad-hoc) signature again."
	exit 0
fi

# valid code signing identities, by name
identities=$(security find-identity -v -p codesigning \
	| sed -n 's/^ *[0-9][0-9]*) [0-9A-F]\{40\} "\(.*\)"$/\1/p')

if [ -z "$identities" ]; then
	echo "No valid code signing certificates found in your keychain." >&2
	echo "Install your certificate (Xcode > Settings > Accounts > Manage Certificates) and try again." >&2
	exit 1
fi

if [ $# -gt 0 ]; then
	identity=$(printf '%s\n' "$identities" | grep -F -- "$1" | head -n 1 || true)
else
	identity=$(printf '%s\n' "$identities" | grep '^Developer ID Application:' | head -n 1 || true)
	if [ -z "$identity" ]; then
		identity=$(printf '%s\n' "$identities" | grep '^Apple Development:' | head -n 1 || true)
	fi
fi

if [ -z "$identity" ]; then
	echo "No matching certificate. Available:" >&2
	printf '  %s\n' "$identities" >&2
	exit 1
fi

# the team ID is the certificate's Organizational Unit (10 characters)
team=$(security find-certificate -c "$identity" -p \
	| openssl x509 -noout -subject 2>/dev/null \
	| grep -oE 'OU ?= ?[A-Z0-9]{10}' | head -n 1 | grep -oE '[A-Z0-9]{10}$' || true)

if [ -z "$team" ]; then
	echo "Could not read the team ID from \"$identity\"." >&2
	exit 1
fi

cat > "$CONFIG" <<CONFIG
// Written by scripts/configure-signing.sh; not committed (see .gitignore).
// Run "scripts/configure-signing.sh --reset" to go back to the local signature.
CODE_SIGN_IDENTITY = $identity
DEVELOPMENT_TEAM = $team
OTHER_CODE_SIGN_FLAGS = --timestamp
CONFIG

echo "Wrote $CONFIG:"
echo "  identity: $identity"
echo "  team:     $team"
case "$identity" in
	"Developer ID Application:"*)
		echo "This certificate can sign builds for distribution. Use scripts/release.sh to"
		echo "build, notarize and package one." ;;
	*)
		echo "Note: this is not a Developer ID certificate. Builds will run on your own Macs"
		echo "with a stable signature, but can't be notarized or given to other people."
		echo "For that you need a \"Developer ID Application\" certificate." ;;
esac
