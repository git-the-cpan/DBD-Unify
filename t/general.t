#!perl -w

BEGIN { $tests = 12 }

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

my $schema = "SYS";
my $dbh    = DBI->connect ("dbi:Unify:", "", $schema);

unless ($dbh) {
    warn "Unable to connect to Unify ($DBI::errstr)\nTests skiped.\n";
    print "1..0\n";
    exit 0;
    }

print "1..$tests\n";

# also test preparse doesn't get confused by ? :1
my $sth = $dbh->prepare (q{
    select * from UNIQ -- ? :1
    });
ok (0, $sth->execute);
ok (0, $sth->{NUM_OF_FIELDS});
eval { my $typo = $sth->{NUM_OFFIELDS_typo} };
ok (0, $@ =~ /attribute/);
ok (0, $sth->{Active});
ok (0, $sth->finish);
ok (0, !$sth->{Active});
undef $sth;		# Force destroy

$sth = $dbh->prepare ("select * from UNIQ");
ok (0, $sth->execute);
ok (0, $sth->{Active});
1 while ($sth->fetch);	# fetch through to end
ok (0, !$sth->{Active});
undef $sth;

eval {
    $dbh->{RaiseError} = 1;
    $dbh->do ("some invalid sql statement");
    };
ok (0, $@ =~ /DBD::Unify::db do failed:/, "eval error: ``$@'' expected 'do failed:'");
$dbh->{RaiseError} = 0;

# ---

ok (0,  $dbh->ping);
$dbh->disconnect;
$dbh->{PrintError} = 0;
ok (0, !$dbh->ping);

exit 0;
