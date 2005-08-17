#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 40;

BEGIN { use_ok ("DBI") }

my $dbh;
ok ($dbh = DBI->connect ("dbi:Unify:", "", ""), "connect");

unless ($dbh) {
    BAILOUT ("Unable to connect to Unify ($DBI::errstr)\n");
    exit 0;
    }

ok (1, "-- table ()");
my @tbl;
ok (@tbl = $dbh->tables (), "tables ()");
s/"//g for @tbl;
my %tbl = map { $_ => 1 } @tbl;
ok (exists $tbl{"SYS.ACCESSIBLE_TABLES"}, "base table existance");

my ($catalog, $schema, $table, $type, $rw);
ok (1, "-- table_info ()");
my $sth; # $dbh->table_info () returns a handle to be fetched
ok ($sth = $dbh->table_info (), "table_info ()");
ok ($sth->bind_columns (\($catalog, $schema, $table, $type, $rw)), "bind");
my $n = 0;
$n++ while $sth->fetch;
ok ($n == @tbl,		"table count");
ok ($sth->finish,	"finish");
ok ($sth = $dbh->table_info (undef), "table_info (undef)");
ok ($sth->finish,	"finish");
ok ($sth = $dbh->table_info (""), "table_info ('')");
ok ($sth->finish,	"finish");
ok (!$dbh->table_info ("DBUTIL"), "table_info ('DBUTIL')");
ok ($sth->finish,	"finish");
ok ($sth = $dbh->table_info (undef, "DBUTIL"), "table_info (undef, 'DBUTIL')");
ok ($sth->bind_columns (\($catalog, $schema, $table, $type, $rw)), "bind");
$n = 0;
$n++ while $sth->fetch;
ok (($n == grep m/^DBUTIL\./ => @tbl), "count DBUTIL tables");
ok ($sth->finish,	"finish");
ok ($sth = $dbh->table_info (undef, "DIRS"), "table_info (undef, 'DIRS')");
ok ($sth->bind_columns (\($catalog, $schema, $table, $type, $rw)), "bind");
$n = 0;
$n++ while $sth->fetch;
ok ($n == 0, "DIRS is a table, not a schema");
ok ($sth->finish,	"finish");
ok ($sth = $dbh->table_info (undef, undef, "DIRS"), "table_info (undef, undef, 'DIRS')");
ok ($sth->bind_columns (\($catalog, $schema, $table, $type, $rw)), "bind");
$n = 0;
$n++ while $sth->fetch;
ok ($n == 1,		"count DIRS tables");
ok ($schema eq "DBUTIL", "table schema");
ok ($type   eq "T",      "table type");
ok ($rw     eq "W",      "table read only");
ok ($sth->finish,	"finish");
ok ($sth = $dbh->table_info (undef, undef, "DIRS", "T"), "table_info (undef, undef, 'DIRS', 'T')");
ok ($sth->bind_columns (\($catalog, $schema, $table, $type, $rw)), "bind");
$n = 0;
$n++ while $sth->fetch;
ok ($n == 1,		"count DIRS Tables");
ok ($sth->finish,	"finish");

ok (1, "-- link_info ()");
# This is still to be converted to foreign_key_info () !
ok ($sth = DBD::Unify::db::link_info ($dbh), "link_info ()");
ok ($sth->finish,	"finish");

ok ($dbh->rollback,	"rollback");
ok ($dbh->disconnect,	"disconnect");

exit 0;
