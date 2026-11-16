#!/bin/sh
# Run the test suite in Vim and Neovim (whichever are installed).
set -u
cd "$(dirname "$0")/.." || exit 1
out=$(mktemp)
trap 'rm -f "$out"' EXIT
status=0
ran=0
for editor in vim nvim; do
  command -v "$editor" >/dev/null 2>&1 || continue
  ran=1
  : >"$out"
  if [ "$editor" = vim ]; then
    ALIAS_TEST_OUT=$out vim -N -u NONE -i NONE --not-a-term -S test/test.vim >/dev/null 2>&1
  else
    ALIAS_TEST_OUT=$out nvim --headless -u NONE -i NONE -S test/test.vim >/dev/null 2>&1
  fi
  rc=$?
  echo "== $editor"
  cat "$out"
  if [ "$rc" -ne 0 ] || ! grep -q '^all passed$' "$out"; then
    status=1
  fi
done
[ "$ran" -eq 1 ] || { echo 'neither vim nor nvim found' >&2; exit 1; }
exit "$status"
