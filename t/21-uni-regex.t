#!/usr/bin/perl

use DBI qw(:sql_types);

$verbose =   0;
$ntests  =   5;

my $t = 0;
sub ok ($$)
{
    my ($tst, $ok) = @_;
    $t++;
    $verbose and
	printf STDERR "# %2d: %-20s %s\n", $t, $tst, $ok ? "OK" : "NOT OK";
    ($ok) ? print "ok $t\n" : print "not ok $t\n";
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
	RaiseError    => 1,
	PrintError    => 1,
	AutoCommit    => 0,
	ChopBlanks    => 1,
	uni_verbose   => $verbose,
	uni_scanlevel => 7,
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

{   my $sts = $dbh->prepare (q;
	select COLCODE
	from   SYS.COLTYPE
	where  COLTYPE = 'FLOAT';
	);
    $sts->execute;
    my ($colcode) = $sts->fetchrow_array;
    ok ("equal", $colcode == 8);
    $sts->finish;
    }

#$dbh->{uni_verbose} = 999;
{   my $sts = $dbh->prepare (q;
	select COLCODE
	from   SYS.COLTYPE
	where  COLTYPE like 'AMOU%';
	);
    $sts->execute;
    my ($colcode) = $sts->fetchrow_array;
    ok ("like", $colcode == 4);
    $sts->finish;
    }

{   my $sts = $dbh->prepare (q;
	select COLCODE
	from   SYS.COLTYPE
	where  COLTYPE reglike '^DOUB.*';
	);
    $sts->execute;
    my ($colcode) = $sts->fetchrow_array;
    ok ("reglike", $colcode == 15);
    $sts->finish;
    }

#if ("This test is known to fail") { ok ("shlike will core", 1) } else
{   my $sts = $dbh->prepare (q;
	select COLCODE
	from   SYS.COLTYPE
	where  COLTYPE shlike 'CHAR*';
	);
    $sts->execute;
    my ($colcode) = $sts->fetchrow_array;
    ok ("shlike", $colcode == 5);
    $sts->finish;
    }

$dbh->disconnect;

1;
