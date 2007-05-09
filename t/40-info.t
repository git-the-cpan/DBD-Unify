#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 59;

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
ok ($sth = $dbh->table_info ({
    TABLE_CAT   => undef,
    TABLE_SCHEM => undef,
    TABLE_NAME  => undef,
    TABLE_TYPE  => undef,
    }), "table_info ({ TABLE_*** => undef })");
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
ok ($sth = $dbh->table_info ({
    TABLE_CAT   => undef,
    TABLE_SCHEM => "DIRS",
    TABLE_NAME  => undef,
    TABLE_TYPE  => undef,
    }), "table_info (undef, 'DIRS')");
ok ($sth->bind_columns (\($catalog, $schema, $table, $type, $rw)), "bind");
$n = 0;
$n++ while $sth->fetch;
is ($n, 0, "DIRS is a table, not a schema");
ok ($sth->finish,	"finish");
ok ($sth = $dbh->table_info ({ TABLE_NAME  => "DIRS" }), "table_info ({ TABLE_NAME => 'DIRS' })");
ok ($sth->bind_columns (\($catalog, $schema, $table, $type, $rw)), "bind");
$n = 0;
$n++ while $sth->fetch;
is ($n, 1,		"count DIRS tables");
is ($schema, "DBUTIL",	"table schema");
is ($type,   "T",	"table type");
is ($rw,     "W",	"table read only");
ok ($sth->finish,	"finish");
ok ($sth = $dbh->table_info ({ TABLE_NAME => "DIRS", TABLE_TYPE => "T" }), "table_info ({ TABLE_NAME => 'DIRS', TABLE_TYPE => 'T' })");
ok ($sth->bind_columns (\($catalog, $schema, $table, $type, $rw)), "bind");
$n = 0;
$n++ while $sth->fetch;
is ($n, 1,		"count DIRS Tables");
ok ($sth->finish,	"finish");

ok (1, "-- link_info ()");
ok ($sth = DBD::Unify::db::link_info ($dbh), "::link_info (\$dbh)");
ok ($sth->finish,	"finish");
ok ($sth = $dbh->link_info (), "\$dbh->link_info ()");
ok ($sth->finish,	"finish");
ok ($sth = $dbh->link_info ({
    TABLE_SCHEM => $ENV{USCHEMA}||"PUBLIC",
    TABLE_NAME  => "DIRS",
    TABLE_TYPE  => "T"}), "\$dbh->link_info ()");
ok ($sth->finish,	"finish");
ok ($sth = $dbh->link_info (undef, undef, "DIRS", "R"), "\$dbh->link_info (..., 'R')");
ok ($sth->finish,	"finish");
ok ($sth = $dbh->link_info (undef, undef, "DIRS", ""), "\$dbh->link_info (..., '')");
ok ($sth->finish,	"finish");

ok (1, "-- foreign_key_info ()");
ok ($sth = $dbh->foreign_key_info (undef, undef, undef, undef, undef, undef),
			"foreign_key_info (undef ...)");
ok ($sth->finish,	"finish");
ok ($sth = $dbh->foreign_key_info (undef, $ENV{USCHEMA}||"PUBLIC", undef,
				   undef, undef, undef),
			"foreign_key_info (SCHEMA, ...)");
ok ($sth->finish,	"finish");
ok ($sth = $dbh->foreign_key_info (undef, $ENV{USCHEMA}||"PUBLIC", undef,
				   undef, $ENV{USCHEMA}||"PUBLIC", undef),
			"foreign_key_info (SCHEMA, SCHEMA, ...)");
ok ($sth->finish,	"finish");
ok ($sth = $dbh->foreign_key_info (undef, $ENV{USCHEMA}||"PUBLIC", "foo",
				   undef, $ENV{USCHEMA}||"PUBLIC", "foo"),
			"foreign_key_info (SCHEMA.foo, SCHEMA.foo)");
ok ($sth->finish,	"finish");

ok ($dbh->rollback,	"rollback");
ok ($dbh->disconnect,	"disconnect");

exit 0;
