#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

candidate=FHEM/98_PID20.pm
fixture=tests/fixtures/98_PID20-old-behavior.pm
candidate_hash=$(sha256sum "$candidate" | awk '{print $1}')
fixture_hash=$(sha256sum "$fixture" | awk '{print $1}')
red_log="${TMPDIR:-/tmp}/pid20-red-$$.log"
trap 'rm -f "$red_log"' EXIT HUP INT TERM

perl -c tests/test-pid20.pl

set +e
perl tests/test-pid20.pl "./$fixture" "$fixture_hash" legacy-mutant >"$red_log" 2>&1
red_result=$?
set -e

test "$red_result" -ne 0 || { echo 'FAIL: expected old behavior to fail'; exit 1; }
grep -q 'DYNAMISCHER_REVERSE_TEST: reverseAction kehrt D nicht um' "$red_log" || {
  echo 'FAIL: old behavior did not fail at the expected D-sign assertion'
  cat "$red_log"
  exit 1
}

echo 'PID20_RED_OK: old D-sign behavior detected'
perl tests/test-pid20.pl "./$candidate" "$candidate_hash"
echo 'PID20_GREEN_OK: community module passes the regression suite'

perl -e '
  my $rule = qr{fhem\.de.*:FHEM/98_PID20\.pm};
  my $official = "https://fhem.de/fhemupdate/controls_fhem.txt:FHEM/98_PID20.pm";
  my $community = "https://raw.githubusercontent.com/parussel/PID20/main/controls_pid20.txt:FHEM/98_PID20.pm";
  die "official source not excluded\n" unless $official =~ $rule;
  die "community source incorrectly excluded\n" if $community =~ $rule;
  print "UPDATE_POLICY_OK: official PID20 excluded; community PID20 allowed\n";
'

perl -e '
  open my $fh, "<", "controls_pid20.txt" or die $!;
  my @lines = grep { /\S/ } <$fh>;
  close $fh;
  die "controls file must contain exactly one module entry\n" unless @lines == 1;
  my @f = split /\s+/, $lines[0];
  my $size = -s "FHEM/98_PID20.pm";
  die "wrong module in controls file\n" unless $f[0] eq "UPD" && $f[3] eq "FHEM/98_PID20.pm";
  die "wrong module size in controls file\n" unless $f[2] == $size;
  print "CONTROLS_FILE_OK: only module file listed; size $size bytes\n";
'
