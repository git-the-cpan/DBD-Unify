#!perl -w

# Test if all of the documented DBI API is implemented and working OK

BEGIN { $tests = 16 }

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

ok (0,  $dbh->{Warn});
ok (0,  $dbh->{Active});
ok (0,  $dbh->{Kids} == 0);
ok (0, !$dbh->{CachedKids} || 0 == keys %{$dbh->{CachedKids}});
ok (0,  $dbh->{ActiveKids} == 0);
ok (0, !$dbh->{CompatMode});

# =============================================================================

my @tables = $dbh->tables;
ok (0, 1 == grep m/^SYS\.ACCESSIBLE_TABLES$/, @tables);
   @tables = $dbh->tables (undef, "SYS", "ACCESSIBLE_COLUMNS", "VIEW");
ok (0, @tables == 1 && $tables[0] eq "SYS.ACCESSIBLE_COLUMNS");

# =============================================================================

# Lets assume this is a default installation, and the DBA has *not* removed
# the DIRS table ;-)

my $rv = $dbh->do ("update DIRS set DIRNAME = 'Foo' where DIRNAME = '^#!\" //'");
ok (0, $rv == 1);
#$rv = \$dbh->do ("update DIRS set DIRNAME = 'Foo' where DIRNAME = '^#!\" //'",
#    { DBDverbose => 1 });
print "ok ", ++$t, " # todo: attibs unused in \$dbh->do ()\n";
#ok (0, $rv == 1);
#$rv = $dbh->do ("update DIRS set DIRNAME = ? where DIRNAME = ?",
#    { DBDverbose => 1 },
#    'Foo', '^#!\" //');
#ok (0, $rv == 1);
print "ok ", ++$t, " # todo: params unused in \$dbh->do ()\n";

$rv = $dbh->rollback;
ok (0, $rv == 1);

$rv = $dbh->commit;
ok (0, $rv == 1);

$rv = $dbh->do ("update DIRS set DIRNAME = 'Foo' where DIRNAME = '^#!\" //'");
# =============================================================================

$dbh->disconnect;
ok (0, !$dbh->{Active});
ok (0, !$dbh->ping);

exit 0;
