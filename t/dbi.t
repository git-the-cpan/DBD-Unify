#!/usr/bin/perl

use DBI qw(:sql_types);

$verbose = 1;# unless defined $verbose;

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

sub connect_db ($)
{
    # Connects to the database.
    # If this fails everything else is in vain!
    my ($dbname) = @_;

    $verbose and
	print "Testing: DBI->connect ('$dbname'):\n";

    my $dbh = DBI->connect ($dbname, undef, "", {
	RaiseError => 1,
	PrintError => 1,
	AutoCommit => 0,
	ScanLevel  => 7,
	ChopBlanks => 1,
#	DBDverbose => 8,
	});
    unless ($dbh) {
        print "1..0\n";
        warn "Cannot connect to database $dbname: $DBI::errstr\n";
        exit 0;
	}
    print "1..1\nok 1\n";
    $dbh;
    } # connect_db

my $dbh = connect_db ($dbname) or die "connect";
$t = 1;

# CREATE THE TABLE
$dbh->do (join " " =>
    "create table xx (",
    "    xs numeric  (4),",
    "    xl numeric  (9),",
    "    xc char     (5),",
    "    xf float       ,",
    "    xa amount (5,2)",
    ")");
$dbh->commit;

# FILL THE TABLE
$dbh->do ("insert into xx values (0,1000,'   ',0.1,0.2)");
foreach my $v ( 1 .. 9 ) {
    $dbh->do ("insert into xx values ($v,100$v,'$v',$v.1,$v.2)");
    }
# FILL THE TABLE, POSITIONAL
my $sth = $dbh->prepare ("insert into xx values (?,?,?,?,?)");
foreach my $v ( 10 .. 18 ) {
    $sth->execute ($v, 1000 + $v, "$v", $v + .1, $v + .2);
    }
$sth->finish ();
$dbh->commit;

# SELECT FROM THE TABLE
$sth = $dbh->prepare ("select * from xx where xs between 4 and 8 or xs = 0");
$sth->execute ();
while (my ($xs, $xl, $xc, $xf, $xa) = $sth->fetchrow_array ()) {
    print STDERR "\t[[$xs, $xl, '$xc', $xf, $xa]]\n";
    }
$sth->finish ();

# SELECT FROM THE TABLE, NESTED
$sth = $dbh->prepare ("select xs from xx where xs in (3, 5)");
$sth->execute ();
while (my ($xs) = $sth->fetchrow_array ()) {
    my $sth2 = $dbh->prepare ("select xl from xx where xs = @{[$xs - 1]}");
    $sth2->execute ();
    if ($sth2) {
	while (my ($xl) = $sth2->fetchrow_array ()) {
	    print STDERR "\t<< $xs => $xl >>\n";
	    }
	}
    $sth2->finish ();
    }
$sth->finish ();

# SELECT FROM THE TABLE, POSITIONAL
$sth = $dbh->prepare ("select xs from xx where xs = ?");
foreach my $xs (3 .. 5) {
    $sth->execute ($xs);
    my ($xc) = $sth->fetchrow_array ();
    print STDERR "\t<< $xs => '$xc' >>\n";
    }
$sth->finish ();

# UPDATE THE TABLE
$dbh->do ("update xx set xf = xf + .05 where xs = 5");
$dbh->commit;

# UPDATE THE TABLE, POSITIONAL
$sth = $dbh->prepare ("update xx set xa = xa + .05 where xs = ?");
$sth->execute (4);
$sth->finish ();
$dbh->commit;

# UPDATE THE TABLE, POSITIONAL TWICE
$sth = $dbh->prepare ("update xx set xc = ? where xs = ?");
$sth->execute ("33", 3);
$sth->finish ();
$dbh->commit;

# UPDATE THE TABLE, POSITIONAL TWICE, NON-KEY
$sth = $dbh->prepare ("update xx set xc = ? where xf = 10.1 and xl = ?");
$sth->execute ("12345", 1010);
$sth->finish ();
$dbh->commit;

$sth = $dbh->prepare ("select * from xx where xs = ?");
$sth->execute (1);
$sth->execute (-1);
$sth->execute ("1");
$sth->execute ("-1");
$sth->execute ("  1");
$sth->execute (" -1");
#$sth->execute ("x");	# Should warn, which it does.
$sth->finish ();

# DROP THE TABLE
$dbh->do ("drop table xx");
$dbh->commit;

$dbh->disconnect;

1;
