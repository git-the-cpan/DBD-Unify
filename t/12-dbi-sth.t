#!perl -w

# Test if all of the documented DBI API is implemented and working OK

BEGIN { $tests = 10 }

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

my $schema = "DBUTIL";
my $dbh    = DBI->connect ("dbi:Unify:", "", $schema);
unless ($dbh) {
    warn "Unable to connect to Unify ($DBI::errstr)\nTests skiped.\n";
    print "1..0\n";
    exit 0;
    }
ok (0, $dbh);

# =============================================================================

# Attributes common to all handles

my $sth = $dbh->prepare ("select * from DIRS");
ok (0,  $dbh->{Kids} == 1);
ok (0,  $sth->{Warn});
ok (0, !$sth->{Active});
ok (0,  $dbh->{ActiveKids} == 0);
$sth->execute;
ok (0,  $sth->{Active});
ok (0,  $dbh->{ActiveKids} == 1);
$sth->finish;
ok (0, !$sth->{Active});
ok (0,  $sth->{Kids} == 0);	# Docs do /not/ define what Kids should return
				# for a statement handle (same for ActiveKids,
				# and CachedKids)
ok (0, !$sth->{CompatMode});

# =============================================================================

$dbh->disconnect;

exit 0;
