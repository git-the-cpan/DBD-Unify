#!perl -w

BEGIN { $tests = 4 }

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

my $schema = "DBUTIL";
my $dbh    = DBI->connect ("dbi:Unify:", "", $schema);

unless ($dbh) {
    warn "Unable to connect to Unify ($DBI::errstr)\nTests skiped.\n";
    print "1..0\n";
    exit 0;
    }

print "1..$tests\n";

my $sth = $dbh->prepare ("select * from DIRS");
ok (0, $sth->execute);
ok (0, $sth->{Active});
$sth->finish;
ok (0, !$sth->{Active});
$dbh->disconnect;	# Should auto-destroy $sth;
ok (0, !$dbh->ping);

exit 0;
