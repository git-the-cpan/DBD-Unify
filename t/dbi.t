#!/usr/bin/perl

use DBI qw(:sql_types);
use vars qw($num_test);

$verbose = 1;# unless defined $verbose;
my $testtable = "testhththt";
my $num_test = 1;

my $t = 0;
sub ok ($$$;$)
{
    my ($n, $ok, $expl, $warn) = @_;
    $t++;
    $n && $n != $t and
	die "Test sequence error, expected $n but actually $t";
    $verbose and
	print "Testing $expl\n";
    ($ok) ? print "ok $t\n" : print "not ok $t\n";
    if (!$ok && $warn) {
	$warn eq "1" and $warn = $DBI::errstr;
	warn "$expl $warn\n";
	}
    } # ok

unless (exists $ENV{UNIFY}  && -d $ENV{UNIFY}) {
    warn "\$UNIFY not set";
    print "1..0\n";
    exit 0;
    }
my $UNIFY  = $ENV{UNIFY};
unless (exists $ENV{DBPATH} && -d $ENV{DBPATH} && -r "$ENV{DBPATH}/file.db") {
    warn "\$DBPATH not set";
    print "1..0\n";
    exit 0;
    }
my $dbname = "DBI:Unify:$ENV{DBPATH}";

sub connect_db ($$)
{
    # Connects to the database.
    # If this fails everything else is in vain!
    my ($num_test, $dbname) = @_;

    $verbose and
	print "Testing: DBI->connect ('$dbname'):\n";

    my $dbh = DBI->connect ($dbname, "", "", { AutoCommit => 0 });
#   $dbh->{ChopBlanks} = 1;
    unless ($dbh) {
        print "1..0\n";
        warn "Cannot connect to database $dbname: $DBI::errstr\n";
        exit 0;
	}
    print "1..$num_test\nok 1\n";
    $dbh;
    } # connect_db

my $dbh = connect_db ($num_test, $dbname);
$t = 1;
$dbh and $dbh->do (join " " =>
    "create table xx (",
    "    xs numeric  (4),",
    "    xl numeric  (9),",
    "    xc char     (5),",
    "    xf float       ,",
    "    xa amount (5,2)",
    ")");
$dbh and $dbh->commit;
foreach my $v ( 1 .. 18 ) {
    $dbh and $dbh->do ("insert into xx values ($v,100$v,'$v',$v.1,$v.2)");
    }
$dbh and $dbh->commit;
$dbh and $sth = $dbh->prepare ("select * from xx where xs between 4 and 9");
$sth and $sth->execute ();
if ($sth) {
    while (my ($xs, $xl, $xc, $xf, $xa) = $sth->fetchrow_array ()) {
	print STDERR "\t[[$xs, $xl, '$xc', $xf, $xa]]\n";
	}
    }
$sth and $sth->finish ();
$dbh and $dbh->do ("drop table xx");
$dbh and $dbh->commit;
$dbh and $dbh->disconnect;

1;

__END__
ok(2, $dbh->do("CREATE TABLE $testtable(id INTEGER4 not null, name CHAR(64))"),
     "Create table", 1);
ok(0, $dbh->do("INSERT INTO $testtable VALUES(1, 'Alligator Descartes')"),
     "Insert(value)", 1);
ok(0, $dbh->do("DELETE FROM $testtable WHERE id = 1"),
     "Delete", 1);

ok(0, $cursor = $dbh->prepare("SELECT * FROM $testtable WHERE id = ? ORDER BY id"),
     "prepare(Select)", 1);
ok(0, $cursor->bind_param(1, 1, {TYPE => SQL_INTEGER}),
     "Bind param 1 as 1", 1);
ok(0, $cursor->execute, "Execute(select)", 1);
$row = $cursor->fetchrow_arrayref;
ok(0, !defined($row), "Fetch from empty table",
     "Row is returned as: ".($row ? DBI->neat_list($row) : "''"));
ok(0, $cursor->finish, "Finish(select)", 1);

ok(0, $cursor->{NAME}[0] eq "id", "Column 1 name",
     "should be 'id' is '$cursor->{NAME}[0]'");
my $null = join  ':', map int($_), @{$cursor->{NULLABLE}};
ok(0, $null eq '0:1',
     "Column nullablility",
     "Should be '0:1' is '$null'");
ok(0, $cursor->{TYPE}[0] == SQL_INTEGER,
     "Column TYPE",
     "should be '".SQL_INTEGER."' is '$cursor->{TYPE}[0]'");
# Possibly needs test on ing_type, ing_ingtype, ing_lengths..


ok(0, $sth = $dbh->prepare("INSERT INTO $testtable(id, name) VALUES(?, ?)"),
     "Prepare(insert with ?)", 1);
ok(0, $sth->bind_param(1, 1, {TYPE => SQL_INTEGER}),
     "Bind param 1 as 1", 1);
ok(0, $sth->bind_param(2, "Henrik Tougaard", {TYPE => SQL_CHAR}),
     "Bind param 2 as string" ,1);
ok(0, $sth->execute, "Execute(insert) with params", 1);
ok(0, $sth->execute( 2, 'Aligator Descartes'),
     "Re-executing(insert)with params", 1);

ok(0, $cursor->execute, "Re-execute(select)", 1);
ok(0, $row = $cursor->fetchrow_arrayref, "Fetching row", 1); 
ok(0, $row->[0] == 1, "Column 1 value",
     "Should be '1' is '$row->[0]'");
ok(0, $row->[1] eq 'Henrik Tougaard', "Column 2 value",
     "Should be 'Henrik Tougaard' is '$row->[1]'");
ok(0, !defined($row = $cursor->fetchrow_arrayref),
     "Fetching past end of data", 
     "Row is returned as: ".($row ? DBI->neat_list($row) : "''"));
ok(0, $cursor->finish, "finish(cursor)", 1);

ok(0, $cursor->execute(2), "Re-execute[select(2)] for chopblanks", 1);
ok(0, $cursor->{ChopBlanks}, "ChopBlanks on by default", 1);
$cursor->{ChopBlanks} = 0;
ok(0, !$cursor->{ChopBlanks}, "ChopBlanks switched off", 1);
ok(0, $row = $cursor->fetchrow_arrayref, "Fetching row", 1); 
ok(0, $row->[1] =~ /^Aligator Descartes\s+/, "Column 2 value",
     "Should be 'Henrik Tougaard   ...  ' is '$row->[1]'");
ok(0, $cursor->finish, "finish(cursor)", 1);

ok(0, $dbh->do(
        "UPDATE $testtable SET id = 3 WHERE name = 'Alligator Descartes'"),
     "do(Update) one row", 1);
ok(0, my $numrows = $dbh->do( "UPDATE $testtable SET id = id+1" ),
     "do(Update) all rows", 1);
ok(0, $numrows == 2, "Number of rows", "should be '2' is '$numrows'");

### Displays all records (for test of the test!)
###$sth=$dbh->prepare("select id, name FROM $testtable");
###$sth->execute;
###while (1) {
###  $row=$sth->fetchrow_arrayref or last;
###  print(DBI::neat_list($row), "\n");
###}
ok(0, $sth=$dbh->prepare("SELECT id, name FROM $testtable WHERE id=3 FOR UPDATE OF name"),
      "prepare for update", 1);
ok(0, $sth->execute, "execute select for update", 1);
ok(0, $row = $sth->fetchrow_arrayref, "Fetching row for update", 1);
ok(0, $dbh->do("UPDATE $testtable SET name='Larry Wall' WHERE CURRENT OF $sth->{CursorName}"), "do cursor update", 1);
ok(0, $sth->finish, "finish select", 1);
ok(0, $sth=$dbh->prepare("SELECT id, name FROM $testtable WHERE id=3"),
      "prepare select after update", 1);
ok(0, $sth->execute, "after update select execute", 1);
ok(0, $row = $sth->fetchrow_arrayref, "fetching row for select_after_update", 1);
ok(0, $row->[1] =~ /^Larry Wall/, "Col 2 value after update",
      "Should be 'Larry Wall...' is '$row->[1]'");
ok(0, $sth->finish, "finish", 1);

### Displays all records (for test of the test!)
###$sth=$dbh->prepare("select id, name FROM $testtable");
###$sth->execute;
###while (1) {
###  $row=$sth->fetchrow_arrayref or last;
###  print(DBI::neat_list($row), "\n");
###}

ok(0, $dbh->do( "DROP TABLE $testtable" ), "Dropping table", 1);
ok(0, $dbh->rollback, "Rolling back", 1);
#   What else??
ok(0, !$dbh->{AutoCommit}, "AutoCommit switched off upon connect time", 1);
$dbh->{AutoCommit}=1;
ok(0, $dbh->{AutoCommit}, "AutoCommit switched on", 1);

ok(0, $dbh->disconnect, "Disconnecting", 1);

$dbh = DBI->connect("$dbname") or die "not ok 999 - died due to $DBI::errstr";
ok(0, $dbh->{AutoCommit}, "AutoCommit switched on by default", 1);
$dbh and $dbh->{AutoCommit}=0;
ok(0, !$dbh->{AutoCommit}, "AutoCommit switched off explicitly", 1);
$dbh and $dbh->commit;
$dbh and $dbh->disconnect;

# Missing:
#   test of outerjoin and nullability
#   what else?

BEGIN { $num_test = 49; }

