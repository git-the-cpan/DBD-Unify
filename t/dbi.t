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

    my $dbh = DBI->connect ($dbname, undef, "", {
	AutoCommit => 0,
	ScanLevel  => 7,
	ChopBlanks => 1,
	});
#   $dbh->{ChopBlanks} = 1;
    unless ($dbh) {
        print "1..0\n";
        warn "Cannot connect to database $dbname: $DBI::errstr\n";
        exit 0;
	}
    print "1..$num_test\nok 1\n";
    $dbh;
    } # connect_db

my $dbh = connect_db ($num_test, $dbname) or die "connect";
$t = 1;
$dbh->do (join " " =>
    "create table xx (",
    "    xs numeric  (4),",
    "    xl numeric  (9),",
    "    xc char     (5),",
    "    xf float       ,",
    "    xa amount (5,2)",
    ")");
$dbh->commit;
$dbh->do ("insert into xx values (0,1000,'   ',0.1,0.2)");
foreach my $v ( 1 .. 18 ) {
    $dbh->do ("insert into xx values ($v,100$v,'$v',$v.1,$v.2)");
    }
$dbh->commit;
$sth = $dbh->prepare ("select * from xx where xs between 4 and 8 or xs = 0");
$sth and $sth->execute ();
if ($sth) {
    while (my ($xs, $xl, $xc, $xf, $xa) = $sth->fetchrow_array ()) {
	print STDERR "\t[[$xs, $xl, '$xc', $xf, $xa]]\n";
	}
    }
$sth and $sth->finish ();

$sth = $dbh->prepare ("select xs from xx where  xs in (3, 5)");
$sth and $sth->execute ();
if ($sth) {
    while (my ($xs) = $sth->fetchrow_array ()) {
	my $sth2 = $dbh->prepare ("select xl from xx where xs = @{[$xs - 1]}");
	$sth2 and $sth2->execute ();
	if ($sth2) {
	    while (my ($xl) = $sth2->fetchrow_array ()) {
		print STDERR "\t<< $xs => $xl >>\n";
		}
	    }
	$sth2 and $sth2->finish ();
	}
    }
$sth and $sth->finish ();

$dbh->do ("drop table xx");
$dbh->commit;

$dbh->disconnect;

1;
