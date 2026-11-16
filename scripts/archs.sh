# Sourced by bundle.sh (zsh). Sweep ships as a universal app: Apple silicon and Intel.
SWEEP_ARCHS=(arm64 x86_64)

# Prints each architecture in SWEEP_ARCHS that the Mach-O file lacks (nothing when all are there,
# every one when the file is missing or not Mach-O).
missing_archs() {
  local have=" $(lipo -archs "$1" 2>/dev/null) " a
  for a in $SWEEP_ARCHS; do [[ $have == *" $a "* ]] || print -r -- $a; done
}

# The executables in Sweep.app that must be universal: Sweep and every part of Sparkle.framework.
app_binaries() {
  local fw=$1/Contents/Frameworks/Sparkle.framework/Versions/B
  print -l -- "$1/Contents/MacOS/Sweep" "$fw/Sparkle" "$fw/Autoupdate" "$fw/Updater.app/Contents/MacOS/Updater" \
    "$fw/XPCServices/Installer.xpc/Contents/MacOS/Installer" \
    "$fw/XPCServices/Downloader.xpc/Contents/MacOS/Downloader"
}

# Fails (and names the file) when any executable in the app lacks an architecture.
check_universal() {
  local f m
  for f in ${(f)"$(app_binaries "$1")"}; do
    m=$(missing_archs "$f")
    [[ -z $m ]] || { echo "error: ${f#$1/} lacks ${(j:, :)${(f)m}} (needs ${(j: + :)SWEEP_ARCHS})" >&2; return 1; }
  done
}
