#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 24;

# Test if all of the documented DBI API is implemented and working OK

BEGIN { use_ok ("DBI") }

# =============================================================================

# DBI Class Methods

my $dbh;

# -- connect

ok ($dbh = DBI->connect ("dbi:Unify:", "", ""), "connect");
ok ($dbh->disconnect, "disconnect");
undef $dbh;

ok ($dbh = DBI->connect ("dbi:Unify:", "", "", { PrintError => 0 }), "connect");

# -- connect_cached

# connect_cached (available as of DBI 1.14) is tested in the DBI test suite.
# Tests here would add nothing cause it's not DBD dependent.

# -- available drivers

my @driver_names = DBI->available_drivers;
like ("@driver_names", qr/\bunify\b/i, "Unify available");
ok ((1 == grep m/^Unify$/ => @driver_names), "Only one Unify available");

# -- data_sources

my @data_sources = DBI->data_sources ("Unify");
ok (@data_sources == 0 || !$data_sources[0], "Unify has no centralized source repository");

# -- trace

my ($trcfile, $rv) = ("/tmp/dbi-trace.$$");
ok (!DBI->trace (1, $trcfile), "set trace file");
ok (1 == DBI->trace (0, $trcfile), "reset trace file");
open TRC, "< $trcfile";
my $line = <TRC>;
like ($line, qr{\btrace level set to (?:[O0]x0*)?/?1\b}, "trace level");

# =============================================================================

# DBI Utility functions

# These are tested in the DBI test suite. Not viable for DBD testing.

# =============================================================================

# DBI Dynamic Attributes

my $sth;

# -- err, errstr, state and rows as variables

ok ($sth = $dbh->do ("update foo set baz = 1 where bar = 'Wrong'"), "do update");

ok ($DBI::err    == -2046, "Err -2046");
ok ($DBI::errstr eq "Invalid table name.", "Invalid table name");
ok ($DBI::state  eq "" || $DBI::state eq "S1000", "Err state S1000");
ok ($DBI::rows   == -1, "Err row count");

# Methods common to all handles

# -- err, errstr, state and rows as methods

ok ($dbh->err    == -2046, "Err method");
ok ($dbh->errstr eq "Invalid table name.", "errstr method");
ok ($dbh->state  eq "" || $dbh->state eq "S1000", "state method");
ok ($dbh->rows   == -1, "rows method");

# -- trace_msg

ok ($dbh->trace_msg ("Foo\n") eq "", "trace msg");
ok ($dbh->trace_msg ("Bar\n", 0) eq "1", "trace msg 2");
ok (<TRC> eq "Bar\n", "message from log");

# -- func

#    DBD::Unify has no private functions (yet)

# =============================================================================

ok ($dbh->disconnect, "disconnect");
undef $dbh;

close TRC;
ok ((unlink $trcfile), "unlink");

exit 0;
