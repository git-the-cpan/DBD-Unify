#!perl -w

# Test if all of the documented DBI API is implemented and working OK

BEGIN {
    if (exists $ENV{DBD_UNIFY_SKIP_27}) {
	print "1..0\n";
	exit 0;
	}
    $max_sth = 473;	# Arbitrary limit test count
    $tests   =   4 + $max_sth;
    }

$ENV{MAXSCAN}       = $max_sth + 1;
$ENV{MXOPENCURSORS} = 2 * $max_sth;

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

my $dbh = DBI->connect ("dbi:Unify:");
unless ($dbh) {
    warn "Unable to connect to Unify ($DBI::errstr)\nTests skiped.\n";
    print "1..0\n";
    exit 0;
    }
ok (0, $dbh);

# =============================================================================

my $sts = $dbh->do (join " " => q;
    create table xx (
        xs numeric       (4) not null,
        xl numeric       (9)
	););
ok (0, $sts);
$dbh->commit;

# Now check hitting realloc sth_id with an arbitrary number
my @sti = map { $dbh->prepare ("insert into xx (xs, xl) values ($_, ?)") }
    (0 .. $max_sth);
map { $_->execute (1234) } @sti;
my @sts = map { $dbh->prepare ("select xs, xl from xx where xs = ?") }
    (0 .. $max_sth);
foreach my $i (0 .. $max_sth) {
    $sts[$i]->execute ($i);
    my ($xs, $xl) = $sts[$i]->fetchrow_array;
    ok (0, $xs == $i && $xl == 1234);
    }
map { $_->finish () } @sts, @sti;
$dbh->commit;

# =============================================================================
$dbh->do ("drop table xx");
$dbh->commit;

$dbh->disconnect;
ok (0, !$dbh->ping);

exit 0;
