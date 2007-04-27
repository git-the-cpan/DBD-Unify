#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 21;

# Test if all of the documented DBI API is implemented and working OK

BEGIN { use_ok ("DBI") }

# =============================================================================

my ($schema, $dbh) = ("DBUTIL");
ok ($dbh = DBI->connect ("dbi:Unify:", "", $schema), "connect");

unless ($dbh) {
    BAILOUT ("Unable to connect to Unify ($DBI::errstr)\n");
    exit 0;
    }

# =============================================================================

# Attributes common to all handles

ok ( $dbh->{Warn},		"Warn");
ok ( $dbh->{Active},		"Active");
is ( $dbh->{Kids}, 0,		"Kids");
ok (!$dbh->{CachedKids} || 0 == keys %{$dbh->{CachedKids}}, "CachedKids");
is ( $dbh->{ActiveKids}, 0,	"ActiveKids");
ok (!$dbh->{CompatMode},	"CompatMode");

# =============================================================================

my @tables;
ok (@tables = $dbh->tables, "tables");
ok ((1 == grep m/^SYS\.ACCESSIBLE_TABLES$/, @tables), "SYS.ACCESSIBLE_TABLES");
ok (@tables = $dbh->tables (undef, "SYS", "ACCESSIBLE_COLUMNS", "VIEW"), "tables (args)");
ok (@tables == 1 && $tables[0] eq "SYS.ACCESSIBLE_COLUMNS", "got only one");

# =============================================================================

# Lets assume this is a default installation, and the DBA has *not* removed
# the DIRS table ;-)

ok ($dbh->do ("update DIRS set DIRNAME = 'Foo' where DIRNAME = '^#!\" //'"), "do update");
TODO: {
    local $SIG{__WARN__} = sub {};
    local $TODO = "support attribs in \$dbh->do ()";
    ok ($dbh->do ("update DIRS set DIRNAME = 'Foo' where DIRNAME = '^#!\" //'",
	{ uni_verbose => 1 }), "do () with attributes");

    local $TODO = "support params in \$dbh->do ()";
    ok ($dbh->do ("update DIRS set DIRNAME = ? where DIRNAME = ?",
	{ uni_verbose => 1 },
	"Foo", '^#!\" //'), "do () with params");
    }

ok ($dbh->rollback,	"rollback");
ok ($dbh->commit,	"commit");

ok ($dbh->do ("update DIRS set DIRNAME = 'Foo' where DIRNAME = '^#!\" //'"), "do () reverse");

# =============================================================================

ok ($dbh->disconnect,	"disconnect");
ok (!$dbh->{Active},	"!Active");
ok (!$dbh->ping,	"!ping");

exit 0;
