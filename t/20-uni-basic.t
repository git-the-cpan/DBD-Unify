#!/usr/bin/perl

use DBI qw(:sql_types);

$verbose =   0;
$ntests  =  40;

my $t = 0;
sub ok ($$)
{
    my ($tst, $ok) = @_;
    $t++;
    $verbose and
	printf STDERR "%2d: %-20s %s\n", $t, $tst, $ok ? "OK" : "NOT OK";
    ($ok) ? print "ok $t\n" : print "not ok $t\n";
    } # ok

unless (exists $ENV{UNIFY}  && -d $ENV{UNIFY}) {
    warn "\$UNIFY not set";
    print "1..0\n";
    exit 0;
    }
my $UNIFY  = $ENV{UNIFY};
local $ENV{DATEFMT} = 'MM/DD/YY';

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
	RaiseError  => 1,
	PrintError  => 1,
	AutoCommit  => 0,
	ScanLevel   => 7,
	ChopBlanks  => 1,
	uni_verbose => $verbose,
	});
    unless ($dbh) {
        print "1..0\n";
        warn "Cannot connect to database $dbname: $DBI::errstr\n";
        exit 0;
	}
    print "1..$ntests\nok 1\n";
    $dbh;
    } # connect_db

my $dbh = connect_db ($dbname) or die "connect";
$t = 1;

# CREATE THE TABLE
$dbh->do (join " " =>
    "create table xx (",
    "    xs numeric       (4) not null,",
    "    xl numeric       (9),",
    "    xc char          (5),",
    "    xf float            ,",
    "    xr real             ,",
    "    xa amount      (5,2),",
    "    xh huge amount (9,2),",
    "    xt time             ,",
    "    xd date             ,",
    "    xe huge date         ",
    ")");
$dbh->commit;

# FILL THE TABLE
$dbh->do ("insert into xx values (0,1000,'   ',0.1,0.2,0.3,1000.4,12:40,11/11/89,7/21/00)");
foreach my $v ( 1 .. 9 ) {
    $dbh->do ("insert into xx values ($v,100$v,'$v',$v.1,$v.2,$v.3,100$v.4,"
    	."12:40,5/20/06,7/21/00)");
    }
# FILL THE TABLE, POSITIONAL
my $sth = $dbh->prepare ("insert into xx values (?,?,?,?,?,?,?,?,?,?)");
foreach my $v ( 10 .. 18 ) {
    $sth->execute ($v, 1000 + $v, "$v", $v + .1, $v + .2, $v + .3, 1000.4 + $v,
    	'11:31', '2/28/93', '11/21/89');
    }
$sth->finish;
$dbh->commit;

$" = ", ";
# SELECT FROM THE TABLE
my %result_ok = (
    0 => "0, 1000, '', 0.100000, 0.200000, 0.30, 1000.40, 12:40, 11/11/89, 07/21/00",

    4 => "4, 1004, '4', 4.100000, 4.200000, 4.30, 1004.40, 12:40, 05/20/06, 07/21/00",
    5 => "5, 1005, '5', 5.100000, 5.200000, 5.30, 1005.40, 12:40, 05/20/06, 07/21/00",
    6 => "6, 1006, '6', 6.100000, 6.200000, 6.30, 1006.40, 12:40, 05/20/06, 07/21/00",
    7 => "7, 1007, '7', 7.100000, 7.200000, 7.30, 1007.40, 12:40, 05/20/06, 07/21/00",
    );
$sth = $dbh->prepare ("select * from xx where xs between 4 and 7 or xs = 0");
# Check the internals
{   local $" = ":";
    my %attr = (
	NAME      => "xs:xl:xc:xf:xr:xa:xh:xt:xd:xe",
	uni_types => "5:2:1:8:7:-4:-6:-7:-3:-11",
	TYPE      => "5:2:1:8:7:6:7:10:9:11",
	PRECISION => "4:9:5:64:32:9:15:0:0:0",
	SCALE     => "0:0:0:0:0:2:2:0:0:0",
	NULLABLE  => "0:1:1:1:1:1:1:1:1:1",	# Does not work in Unify (yet)
	);
    foreach my $attr (qw(NAME uni_types TYPE PRECISION SCALE)) {
	#printf STDERR "\n%-20s %s\n", $attr, "@{$sth->{$attr}}";
	ok ("attr $attr", "@{$sth->{$attr}}" eq $attr{$attr});
	}
    }
$sth->execute;
while (my ($xs, $xl, $xc, $xf, $xr, $xa, $xh, $xt, $xd, $xe) = $sth->fetchrow_array ()) {
    ok ("fetchrow_array",
	$result_ok{$xs} eq "$xs, $xl, '$xc', $xf, $xr, $xa, $xh, $xt, $xd, $xe");
    }
$sth->finish;

$sth = $dbh->prepare ("select xl, xc from xx where xs = 8");
$sth->execute;
my $ref = $sth->fetchrow_arrayref;
ok ("fetchrow_arrayref",
    "@$ref" eq "1008, 8");
$sth->finish;
# test the reexec
$sth->execute;
$ref = $sth->fetchrow_arrayref;
ok ("fetchrow_arrayref",
    "@$ref" eq "1008, 8");
$sth->finish;

$sth = $dbh->prepare ("select xl from xx where xs = 9");
$sth->execute;
$ref = $sth->fetchrow_hashref;
ok ("fetchrow_hashref",
    keys %$ref == 1 && exists $ref->{xl} && $ref->{xl} == 1009);
$sth->finish;

# SELECT FROM THE TABLE, NESTED
$sth = $dbh->prepare ("select xs from xx where xs in (3, 5)");
$sth->execute;
while (my ($xs) = $sth->fetchrow_array ()) {
    my $sth2 = $dbh->prepare ("select xl from xx where xs = @{[$xs - 1]}");
    $sth2->execute;
    if ($sth2) {
	while (my ($xl) = $sth2->fetchrow_array ()) {
	    ok ("fetch nested",
		($xs == 3 || $xs == 5) && $xl == $xs + 999);
	    }
	}
    $sth2->finish;
    }
$sth->finish;

# SELECT FROM THE TABLE, POSITIONAL
$sth = $dbh->prepare ("select xs from xx where xs = ?");
foreach my $xs (3 .. 5) {
    $sth->execute ($xs);
    my ($xc) = $sth->fetchrow_array;
    ok ("fetch positional",
	$xs == $xc);
    }
# Check the bind_columns
{   my $xs = 0;
    $sth->bind_columns (\$xs);
    $sth->execute (3);
    $sth->fetchrow_arrayref;
    ok ("bind_columns",
    	$xs == 3);
    }
$sth->finish;

# UPDATE THE TABLE
$dbh->do ("update xx set xf = xf + .05 where xs = 5");
$dbh->commit;

# UPDATE THE TABLE, POSITIONAL
$sth = $dbh->prepare ("update xx set xa = xa + .05 where xs = ?");
$sth->execute (4);
$sth->finish;
$dbh->commit;

# UPDATE THE TABLE, MULTIPLE RECORDS, and COUNT
$sth = $dbh->prepare ("update xx set xa = xa + .05 where xs = 5 or xs = 6");
$sth->execute;
ok ("rows method", $sth->rows == 2);
$sth->finish;
$dbh->rollback;

# UPDATE THE TABLE, POSITIONAL TWICE
$sth = $dbh->prepare ("update xx set xc = ? where xs = ?");
$sth->execute ("33", 3);
$sth->finish;
$dbh->commit;

# UPDATE THE TABLE, POSITIONAL TWICE, NON-KEY
$sth = $dbh->prepare ("update xx set xc = ? where xf = 10.1 and xl = ?");
$sth->execute ("12345", 1010);
$sth->finish;
$dbh->commit;

$sth = $dbh->prepare ("select * from xx where xs = ?");
$sth->execute (1);
$sth->execute (-1);
$sth->execute ("1");
$sth->execute ("-1");
$sth->execute ("  1");
$sth->execute (" -1");
#$sth->execute ("x");	# Should warn, which it does.
$sth->finish;

# Check final state
my @rec = (
    "0, 1000, , 0.100000, 0.200000, 0.30, 1000.40, 12:40, 11/11/89, 07/21/00",
    "1, 1001, 1, 1.100000, 1.200000, 1.30, 1001.40, 12:40, 05/20/06, 07/21/00",
    "2, 1002, 2, 2.100000, 2.200000, 2.30, 1002.40, 12:40, 05/20/06, 07/21/00",
    "3, 1003, 33, 3.100000, 3.200000, 3.30, 1003.40, 12:40, 05/20/06, 07/21/00",
    "4, 1004, 4, 4.100000, 4.200000, 4.35, 1004.40, 12:40, 05/20/06, 07/21/00",
    "5, 1005, 5, 5.150000, 5.200000, 5.30, 1005.40, 12:40, 05/20/06, 07/21/00",
    "6, 1006, 6, 6.100000, 6.200000, 6.30, 1006.40, 12:40, 05/20/06, 07/21/00",
    "7, 1007, 7, 7.100000, 7.200000, 7.30, 1007.40, 12:40, 05/20/06, 07/21/00",
    "8, 1008, 8, 8.100000, 8.200000, 8.30, 1008.40, 12:40, 05/20/06, 07/21/00",
    "9, 1009, 9, 9.100000, 9.200000, 9.30, 1009.40, 12:40, 05/20/06, 07/21/00",
    "10, 1010, 12345, 10.100000, 10.200000, 10.30, 1010.40, 11:31, 02/28/93, 11/21/89",
    "11, 1011, 11, 11.100000, 11.200000, 11.30, 1011.40, 11:31, 02/28/93, 11/21/89",
    "12, 1012, 12, 12.100000, 12.200000, 12.30, 1012.40, 11:31, 02/28/93, 11/21/89",
    "13, 1013, 13, 13.100000, 13.200000, 13.30, 1013.40, 11:31, 02/28/93, 11/21/89",
    "14, 1014, 14, 14.100000, 14.200000, 14.30, 1014.40, 11:31, 02/28/93, 11/21/89",
    "15, 1015, 15, 15.100000, 15.200000, 15.30, 1015.40, 11:31, 02/28/93, 11/21/89",
    "16, 1016, 16, 16.100000, 16.200001, 16.30, 1016.40, 11:31, 02/28/93, 11/21/89",
    "17, 1017, 17, 17.100000, 17.200001, 17.30, 1017.40, 11:31, 02/28/93, 11/21/89",
    "18, 1018, 18, 18.100000, 18.200001, 18.30, 1018.40, 11:31, 02/28/93, 11/21/89",
    );
$sth = $dbh->prepare ("select * from xx order by xs");
$sth->execute;
while (my @f = $sth->fetchrow_array ()) {
    ok ("final state",
	"@f" eq shift @rec);
    }
$sth->finish;

$dbh->do ("delete xx");
$dbh->commit;

# DROP THE TABLE
$dbh->do ("drop table xx");
$dbh->commit;

$dbh->disconnect;

1;
