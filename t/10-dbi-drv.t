#!perl -w

# Test if all of the documented DBI API is implemented and working OK

BEGIN { $tests = 18 }

sub ok ($$;$) {
    my ($n, $ok, $warn) = @_;
    ++$t;
    die "sequence error, expected $n but actually $t"
    if $n and $n != $t;
    ($ok) ? print "ok $t\n"
	  : print "# failed test $t at line ".(caller)[2]."\nnot ok $t\n";
    if (!$ok && $warn) {
	$warn = $DBI::errstr || "(DBI::errstr undefined)" if $warn eq "1";
	warn "$warn\n";
	}
    } # ok

use DBI;
$| = 1;

print "1..$tests\n";

# =============================================================================

# DBI Class Methods

# -- connect

my $dbh = DBI->connect ("dbi:Unify:", "", "");
ok (0, $dbh);
$dbh->disconnect;
undef $dbh;

$dbh = DBI->connect ("dbi:Unify:", "", "", { PrintError => 0 });
ok (0, $dbh);

# -- connect_cached

# connect_cached (available as of DBI 1.14) is tested in the DBI test suite.
# Tests here would add nothing cause it's not DBD dependent.

# -- available drivers

my @driver_names = DBI->available_drivers;
ok (0, 1 == grep m/^Unify$/ => @driver_names);

# -- data_sources

my @data_sources = DBI->data_sources ("Unify");
ok (0, @data_sources == 0 || !$data_sources[0]);

# -- trace

my $trcfile = "/tmp/dbi-trace.$$";
$rv = DBI->trace (1, $trcfile);
ok (0, $rv == 0);
$rv = DBI->trace (0, $trcfile);
ok (0, $rv == 1);
open TRC, "< $trcfile";
ok (0, <TRC> =~ m/\btrace level set to 1\b/);

# =============================================================================

# DBI Utility functions

# These are tested in the DBI test suite. Not viable for DBD testing.

# =============================================================================

# DBI Dynamic Attributes

# -- err, errstr, state and rows as variables

my $sth = $dbh->do ("update foo set baz = 1 where bar = 'Wrong'");
ok (0, $DBI::err    == -2046);
ok (0, $DBI::errstr eq "Invalid table name.");
ok (0, $DBI::state  eq "" || $DBI::state eq "S1000");
ok (0, $DBI::rows   == -1);

# Methods common to all handles

# -- err, errstr, state and rows as methods

ok (0, $dbh->err    == -2046);
ok (0, $dbh->errstr eq "Invalid table name.");
ok (0, $dbh->state  eq "" || $dbh->state eq "S1000");
ok (0, $dbh->rows   == -1);

# -- trace_msg

$rv = $dbh->trace_msg ("Foo\n");
ok (0, $rv eq "");
$rv = $dbh->trace_msg ("Bar\n", 0);
ok (0, $rv eq "1");
ok (0, <TRC> eq "Bar\n");

# -- func

#    DBD::Unify has no private functions (yet)

# =============================================================================

$dbh->disconnect;
undef $dbh;

close TRC;
unlink $trcfile;

exit 0;
