#!/usr/bin/env bash
# Runs every test in tests/ and prints a summary. Exits non-zero if any fail.
# The headless tests always run; the climbing screen test needs a window, so
# it runs under xvfb-run when that's installed (or with a display) and is
# skipped otherwise.
#
#   tests/run_all.sh                 # uses `godot` on the PATH
#   GODOT=/path/to/godot tests/run_all.sh
#
# CI (.github/workflows/tests.yml) runs this on every pull request.
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"

# The import step builds .godot/ (a fresh clone has none); tests need it.
if [ ! -d .godot/imported ]; then
	"$GODOT" --headless --path . --import > /dev/null 2>&1
fi

failed=()
run() {
	local name="$1"
	shift
	local start=$SECONDS
	if "$@" > "/tmp/yosemite_${name}.log" 2>&1; then
		printf 'PASS  %-16s %4ss\n' "$name" $((SECONDS - start))
	else
		printf 'FAIL  %-16s %4ss  (log: /tmp/yosemite_%s.log)\n' "$name" $((SECONDS - start)) "$name"
		grep -E '^FAIL|SCRIPT ERROR' "/tmp/yosemite_${name}.log" | head -20 | sed 's/^/      /'
		failed+=("$name")
	fi
}

for scene in tests/*_test.tscn; do
	name="$(basename "$scene" .tscn)"
	if [ "$name" = "climb_screen_test" ]; then
		continue
	fi
	run "$name" "$GODOT" --headless --path . "res://$scene"
done

if [ -n "${DISPLAY:-}" ]; then
	run climb_screen_test "$GODOT" --path . res://tests/climb_screen_test.tscn
elif command -v xvfb-run > /dev/null; then
	run climb_screen_test xvfb-run -a "$GODOT" --path . res://tests/climb_screen_test.tscn
else
	echo "SKIP  climb_screen_test (needs a window: install xvfb)"
fi

if [ ${#failed[@]} -gt 0 ]; then
	echo "${#failed[@]} test(s) failed: ${failed[*]}"
	exit 1
fi
echo "All tests passed."
