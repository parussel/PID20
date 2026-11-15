#!/usr/bin/perl
use strict;
use warnings;
use FindBin;

use vars qw(%defs %attr %modules $readingFnAttributes $init_done $now);

my $module = $ENV{PID20_MODULE} // "$FindBin::Bin/../FHEM/98_PID20.pm";
$readingFnAttributes = '';
$init_done = 1;
$now = 1_700_000_000;
my @commands;
my $test_number = 0;
my $failures = 0;

sub ok {
    my ($condition, $description) = @_;
    ++$test_number;
    ++$failures unless $condition;
    print(($condition ? 'ok ' : 'not ok '), "$test_number - $description\n");
    return $condition;
}

sub Log3 { return; }
sub IsDisabled { return 0; }
sub gettimeofday { return $now; }
sub TimeNow { return "$now"; }
sub time_str2num { return 0 + ($_[0] // 0); }
sub AttrVal {
    my ($device, $key, $default) = @_;
    return exists $attr{$device}{$key} ? $attr{$device}{$key} : $default;
}
sub ReadingsVal {
    my ($device, $reading, $default) = @_;
    return exists $defs{$device}{READINGS}{$reading}{VAL}
      ? $defs{$device}{READINGS}{$reading}{VAL}
      : $default;
}
sub ReadingsTimestamp {
    my ($device, $reading, $default) = @_;
    return exists $defs{$device}{READINGS}{$reading}{TIME}
      ? $defs{$device}{READINGS}{$reading}{TIME}
      : $default;
}
sub readingsBeginUpdate { return; }
sub readingsBulkUpdate {
    my ($hash, $reading, $value) = @_;
    $hash->{READINGS}{$reading}{VAL} = $value;
    $hash->{READINGS}{$reading}{TIME} = "$now";
    return;
}
sub readingsEndUpdate { return; }
sub readingsSingleUpdate { return readingsBulkUpdate(@_); }
sub InternalTimer { return; }
sub RemoveInternalTimer { return; }
sub setNotifyDev { return; }
sub fhemTimeLocal { return time; }
sub fhem {
    my ($command) = @_;
    $command =~ s/\s+/ /g;
    $command =~ s/^\s+|\s+$//g;
    push @commands, $command;
    return;
}

my $loaded = do $module;
die "Unable to load $module: $@ $!\n" unless $loaded;

sub make_pid {
    my ($suffix, $error_action, $with_desired) = @_;
    my $pid = "PID_$suffix";
    my $sensor = "Sensor_$suffix";
    my $actor = "Actor_$suffix";

    $defs{$sensor} = {
        NAME => $sensor,
        READINGS => { temperature => { VAL => 20, TIME => ''.($now - 361) } },
    };
    $defs{$actor} = { NAME => $actor, TYPE => 'dummy', READINGS => {} };
    $defs{$pid} = {
        NAME => $pid,
        helper => {
            sensor => $sensor,
            reading => 'temperature',
            regexp => '([-+]?[0-9]*\\.?[0-9]+)',
            actor => $actor,
            actorCommand => 'position',
            actorTimestamp => ''.($now - 10),
            deltaGradient => 0,
            adjust => '',
            stopped => 0,
        },
        READINGS => {
            actuation => { VAL => 75, TIME => ''.($now - 10) },
            actuationCalc => { VAL => 75, TIME => ''.($now - 10) },
            p_i => { VAL => 0, TIME => ''.($now - 10) },
            delta => { VAL => 10, TIME => ''.($now - 10) },
        },
    };
    $defs{$pid}{READINGS}{desired} = { VAL => 30, TIME => "$now" } if $with_desired;
    $attr{$pid} = {
        pidActorErrorAction => $error_action,
        pidActorErrorPos => 1,
        pidSensorTimeout => 360,
        pidActorLimitLower => 1,
        pidActorLimitUpper => 100,
        pidActorInterval => 180,
        pidActorKeepAlive => 1800,
        pidActorTreshold => 2,
        pidActorValueDecPlaces => 0,
        pidCalcInterval => 60,
        pidDeltaTreshold => 0.1,
        pidFactor_P => 1,
        pidFactor_I => 0,
        pidFactor_D => 0,
    };
    return ($pid, $sensor, $actor);
}

my ($error_pid, $error_sensor, $error_actor) = make_pid('ErrorPos', 'errorPos', 1);
@commands = ();
PID20_Calc($error_pid);
ok(@commands == 1 && $commands[0] eq "set $error_actor position 1",
   'dead sensor immediately commands the configured error position');

$now += 60;
PID20_Calc($error_pid);
ok(@commands == 1,
   'the same sensor alarm does not repeat the error command every calculation');

my ($freeze_pid) = make_pid('Freeze', 'freeze', 1);
@commands = ();
PID20_Calc($freeze_pid);
ok(@commands == 0, 'freeze mode keeps its previous no-command behavior');

$now += 200;
$defs{$error_sensor}{READINGS}{temperature}{TIME} = "$now";
@commands = ();
PID20_Calc($error_pid);
ok(@commands == 1 && $commands[0] ne "set $error_actor position 1",
   'a recovered sensor resumes ordinary PID output');

my ($missing_pid) = make_pid('MissingDesired', 'errorPos', 0);
$defs{'Sensor_MissingDesired'}{READINGS}{temperature}{TIME} = "$now";
@commands = ();
PID20_Calc($missing_pid);
ok(@commands == 0, 'a missing desired value does not trigger the sensor failsafe');

print "1..$test_number\n";
exit($failures ? 1 : 0);
