#!/usr/bin/perl
use strict;
use warnings;
use Digest::SHA qw(sha256_hex);
use Time::HiRes qw(gettimeofday);
use FindBin;
use vars qw(%defs %attr %modules $readingFnAttributes $init_done);

$SIG{__WARN__} = sub { die "STOP: Perl-Warnung: @_" };

my $module = $ARGV[0] // "$FindBin::Bin/../FHEM/98_PID20.pm";
my $expected = $ARGV[1] // '6f629fa7488f4da35bdb7bca0d940463634623c0a27a01fc49cea28738fa31eb';
my $mode = $ARGV[2] // 'candidate';
open my $fh, '<:raw', $module or die "STOP: Modul fehlt: $!\n";
my $bytes = do { local $/; <$fh> };
close $fh;
die "STOP: Modul-Pruefsumme abweichend\n" unless sha256_hex($bytes) eq $expected;
die "STOP: Chat/Markdown-Escapes im Modul gefunden\n"
  if $bytes =~ /\\(?:\(|\)|vert\{\})/;

$readingFnAttributes = '';
$init_done = 1;
my @commands;

sub assert_true { die "STOP: $_[1]\n" unless $_[0]; }
sub approx { return abs($_[0] - $_[1]) < 0.02; }
sub Log3 { return; }
sub IsDisabled { return 0; }
sub TimeNow { return scalar localtime; }
sub FmtDateTime { return TimeNow(); }
sub time_str2num { return gettimeofday() - 10; }
sub ReadingsTimestamp { return TimeNow(); }
sub ReadingsVal {
  my ($device, $reading, $default) = @_;
  return exists $defs{$device}{READINGS}{$reading}{VAL}
    ? $defs{$device}{READINGS}{$reading}{VAL} : $default;
}
sub AttrVal {
  my ($device, $key, $default) = @_;
  return exists $attr{$device}{$key} ? $attr{$device}{$key} : $default;
}
sub CommandSet {
  my ($ignored, $command) = @_;
  die "STOP: Stellbefehl nicht an Dummy-Aktor gerichtet: $command\n"
    unless $command =~ /^PID20_TestAktor(?:\s+.*)?$/;
  push @commands, $command;
  return;
}
sub fhem {
  my ($command) = @_;
  die "STOP: Stellbefehl nicht an Dummy-Aktor gerichtet: $command\n"
    unless $command =~ /^set PID20_TestAktor (?:position )?-?[0-9.]+$/;
  push @commands, $command;
  return;
}
sub readingsBeginUpdate { return; }
sub readingsBulkUpdate { $_[0]{READINGS}{$_[1]}{VAL} = $_[2]; return; }
sub readingsEndUpdate { return; }
sub readingsSingleUpdate { $_[0]{READINGS}{$_[1]}{VAL} = $_[2]; return; }
sub InternalTimer { return; }
sub RemoveInternalTimer { return; }
sub deviceEvents { return $_[0]{CHANGED}; }
sub fhemTimeLocal { return time; }
sub setNotifyDev { return; }

my $loaded = do $module;
die "STOP: Modul konnte nicht geladen werden: $@ $!\n" unless $loaded;

my $type = {};
PID20_Initialize($type);
assert_true($type->{AttrList} =~ /pidDIntegration/, 'Attribut pidDIntegration fehlt');
assert_true($bytes =~ /reverseAction[^\n]*\?\s*-[\$]deltaGradient\s*:\s*[\$]deltaGradient/,
  'D-Anteil wird bei reverseAction nicht sichtbar umgekehrt');

my $pid = 'PID20_TestRegler';
my $sensor = 'PID20_TestFuehler';
my $actor = 'PID20_TestAktor';
$defs{$pid} = {
  NAME => $pid,
  DEF => "$sensor:temperature $actor",
  helper => { sensor => $sensor, reading => 'temperature', regexp => '([-+]?[0-9]*\\.?[0-9]+)', actor => $actor },
  READINGS => { desired => { VAL => 20 } },
};
$defs{$sensor} = { NAME => $sensor, READINGS => { temperature => { VAL => 14 } }, CHANGED => ['temperature: 14'] };
$defs{$actor} = { NAME => $actor, TYPE => 'dummy', READINGS => {} };
$attr{$pid}{pidDIntegration} = 3;

my $now = gettimeofday();
$defs{$pid}{helper}{deltaHistory} = [
  [$now - 3, 10], [$now - 2, 8], [$now - 1, 9]
];
PID20_Notify($defs{$pid}, $defs{$sensor});
my $gradient = $defs{$pid}{helper}{deltaGradient};
assert_true(approx($gradient, -1.1), "lineare Regression falsch: $gradient statt ca. -1.1");
assert_true(@{$defs{$pid}{helper}{deltaHistory}} == 4, 'Historienlaenge falsch');
print "DUMMY_FUEHLER: vier Messpunkte verarbeitet\n";
print "D_GLAETTUNG: Regressionssteigung ca. -1.1 korrekt\n";

$attr{$pid}{pidDIntegration} = 1;
$defs{$pid}{helper}{deltaHistory} = [[$now - 2, 8]];
$defs{$sensor}{READINGS}{temperature}{VAL} = 14;
PID20_Notify($defs{$pid}, $defs{$sensor});
$gradient = $defs{$pid}{helper}{deltaGradient};
assert_true(approx($gradient, -1.0), "Kompatibilitaetsmodus falsch: $gradient statt ca. -1.0");
print "KOMPATIBILITAET: pidDIntegration=1 nutzt letzten und aktuellen Wert\n";

if ($mode eq 'candidate') {
  $attr{$pid}{pidDIntegration} = 2;
  $defs{$pid}{helper}{deltaHistory} = [[$now - 2, 9], [$now - 1, 8]];
  $defs{$sensor}{READINGS}{temperature}{VAL} = 14;
  PID20_Notify($defs{$pid}, $defs{$sensor});
  assert_true(@{$defs{$pid}{helper}{deltaHistory}} == 3, 'Historienlaenge fuer Integration=2 falsch');
  print "HISTORIE_3: zwei vorherige plus aktueller Wert korrekt\n";

  $attr{$pid}{pidDIntegration} = 10;
  $defs{$pid}{helper}{deltaHistory} = [map { [$now - 20 + $_, 20 - $_] } 0 .. 14];
  PID20_Notify($defs{$pid}, $defs{$sensor});
  assert_true(@{$defs{$pid}{helper}{deltaHistory}} == 11, 'lange Historie nicht auf 11 Werte begrenzt');
  print "HISTORIE_11: zehn vorherige plus aktueller Wert korrekt begrenzt\n";

  $attr{$pid}{pidDIntegration} = 1;
  $defs{$pid}{helper}{deltaHistory} = [[1000, 8]];
  {
    no warnings 'redefine';
    local *gettimeofday = sub { 1000 };
    PID20_Notify($defs{$pid}, $defs{$sensor});
  }
  assert_true($defs{$pid}{helper}{deltaGradient} == 0,
    'gleiche Zeitstempel muessen einen Gradient von 0 ergeben');
  print "ZEITSTEMPEL_GLEICH: kein Teilen durch null, Gradient=0\n";

  $defs{$pid}{helper}{deltaHistory} = [[$now - 1, 7], [$now, 6]];
  my $global = { NAME => 'global', CHANGED => ['REREADCFG'] };
  PID20_Notify($defs{$pid}, $global);
  assert_true(!exists $defs{$pid}{helper}{deltaHistory} ||
    @{$defs{$pid}{helper}{deltaHistory}} == 0,
    'REREADCFG_LEERT_HISTORIE: alte D-Historie blieb erhalten');
  print "REREADCFG: D-Historie verworfen und Regler neu initialisiert\n";
}

CommandSet(undef, "$actor 37");
assert_true(@commands == 1 && $commands[0] eq 'PID20_TestAktor 37', 'Dummy-Stellbefehl nicht abgefangen');
print "DUMMY_AKTOR: Stellwert 37 ausschliesslich abgefangen\n";

sub run_direction {
  my ($suffix, $reverse) = @_;
  my $name = "PID20_TestRegler_$suffix";
  $defs{$sensor}{READINGS}{temperature}{VAL} = 18;
  $defs{$name} = {
    NAME => $name,
    helper => {
      sensor => $sensor, reading => 'temperature', regexp => '([-+]?[0-9]*\\.?[0-9]+)',
      actor => $actor, actorCommand => 'position', deltaGradient => 0.1,
      adjust => '', stopped => 0,
    },
    READINGS => {
      desired => { VAL => 20 }, p_i => { VAL => 0 }, delta => { VAL => 2 },
    },
  };
  $attr{$name} = {
    pidReverseAction => $reverse,
    pidFactor_P => 10, pidFactor_I => 0, pidFactor_D => 5,
    pidCalcInterval => 60, pidActorLimitLower => -100, pidActorLimitUpper => 100,
    pidActorValueDecPlaces => 0, pidActorTreshold => 1,
  };
  @commands = ();
  PID20_Calc($name);
  return (
    $defs{$name}{READINGS}{p_p}{VAL},
    $defs{$name}{READINGS}{p_d}{VAL},
    $defs{$name}{READINGS}{actuationCalc}{VAL},
    $commands[0] // '',
  );
}

my ($normal_p, $normal_d, $normal_out, $normal_cmd) = run_direction('Normal', 0);
my ($reverse_p, $reverse_d, $reverse_out, $reverse_cmd) = run_direction('Reverse', 1);
assert_true($normal_p == 20 && $normal_d == 30 && $normal_out == 50,
  "Normalrichtung unerwartet: P=$normal_p D=$normal_d Ausgang=$normal_out");
assert_true($reverse_p == -20, "reverseAction kehrt P nicht um: $reverse_p");
assert_true($reverse_d == -30,
  "DYNAMISCHER_REVERSE_TEST: reverseAction kehrt D nicht um: $reverse_d");
assert_true($reverse_out == -50,
  "DYNAMISCHER_REVERSE_TEST: Ausgang falsch: $reverse_out statt -50");
assert_true($normal_cmd eq 'set PID20_TestAktor position 50' &&
  $reverse_cmd eq 'set PID20_TestAktor position -50', 'A/B-Stellbefehle nicht korrekt abgefangen');
print "REVERSE_A_B: normal P=20 D=30 Ausgang=50; reverse P=-20 D=-30 Ausgang=-50\n";
print "PID20_TEST_OK: keine echte Hardware und kein echtes FHEM angesprochen\n";

