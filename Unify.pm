#   Copyright (c) 1999,2000 H.Merijn Brand
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.

require 5.004;

use strict;

use Carp;

=head1 NAME

DBD::Unify - DBI driver for Unify database systems

=head1 SYNOPSIS

    $dbh = DBI->connect ("DBI:Unify:[\$dbname]", "", $schema, {
			    AutoCommit => 0,
			    ChopBlanks => 1,
			    ScanLevel  => 2,
			    });
    $dbh->do ($statement);
    $dbh->commit ();
    $dbh->rollback ();
    $dbh->disconnect ();

    @row = $dbh->selectrow_array ($statement);

    $sth = $dbh->prepare ($statement);
    $sth->execute ();
    @row = $sth->fetchrow_array ();
    $sth->finish ();

    $sth = $dbh->prepare ($statement);	# W/ placeholders like where field = ?
    $sth->execute (3);
    @row = $sth->fetchrow_array ();
    $sth->finish ();
    ...

=cut

# The POD text continues at the end of the file.

###############################################################################

package DBD::Unify;

use DBI 1.12;
use DynaLoader ();

use vars qw(@ISA $VERSION);
$VERSION = "0.05";

@ISA = qw(DynaLoader);
bootstrap DBD::Unify $VERSION;

use vars qw($err $errstr $state $drh);
$err    = 0;		# holds error code   for DBI::err
$errstr = "";		# holds error string for DBI::errstr
$state  = "";		# holds SQL state    for DBI::state
$drh    = undef;	# holds driver handle once initialised

sub driver
{
    return $drh if $drh;
    my ($class, $attr) = @_;

    $class .= "::dr";

    # not a 'my' since we use it above to prevent multiple drivers
    $drh = DBI::_new_drh ($class, {
	Name         => "Unify",
	Version      => $VERSION,
	Err          => \$DBD::Unify::err,
	Errstr       => \$DBD::Unify::errstr,
	State        => \$DBD::Unify::state,
	Attribution  => "DBD::Unify by H.Merijn Brand",
	});

    $drh;
    } # driver

1;

####### Driver ################################################################

package DBD::Unify::dr;

$DBD::Unify::dr::imp_data_size = 0;

sub connect
{
    my ($drh, $dbname, $user, $auth) = @_;

    unless ($ENV{UNIFY} && -d $ENV{UNIFY} && -x _) {
	carp ("\$UNIFY not set or invalid. UNIFY may fail\n")
	    if $drh->{Warn};
	}
    # More checks here if wanted ...

    # create a 'blank' dbh
    my $dbh = DBI::_new_dbh ($drh, {
	Name          => $dbname,
	USER          => $user,
	CURRENT_USER  => $user,
	});

    $user = "" unless defined $user;
    $auth = "" unless defined $auth;
    
    # Connect to the database..
    DBD::Unify::db::_login ($dbh, $dbname, $user, $auth)
	or return undef;

    $dbh;
    } # connect

sub data_sources
{
    my ($drh) = @_;
    Carp::carp "\$drh->data_sources() not defined for Unify\n"
	if $drh->{Warn};
    "";
    } # data_sources

####### Database ##############################################################

package DBD::Unify::db;

$DBD::Unify::db::imp_data_size = 0;

sub do
{
    my ($dbh, $statement, $attribs, @params) = @_;
    Carp::carp "DBD::Unify::\$dbh->do () attribs unused\n" if $attribs;
    Carp::carp "DBD::Unify::\$dbh->do () params unused\n"  if @params;
    DBD::Unify::db::_do ($dbh, $statement);
    } # do

sub prepare
{
    my ($dbh, $statement, @attribs) = @_;

    # create a 'blank' sth
    my $sth = DBI::_new_sth ($dbh, {
	Statement => $statement,
	});

    # Setup module specific data
#   $sth->STORE ("driver_params" => []);
#   $sth->STORE ("NUM_OF_PARAMS" => ($statement =~ tr/?//));

    DBD::Unify::st::_prepare ($sth, $statement, @attribs)
	or return undef;

    $sth;
    } # prepare

sub table_info
{
    my ($dbh) = @_;
    my $sth = $dbh->prepare ("select * from SYS.ACCESSIBLE_TABLES");
    $sth or return;
    $sth->execute ();
    $sth;
    } # table_info

#sub ping
#{
#    my ($dbh) = @_;
#    # we know that DBD::Unify prepare does a describe so this will
#    # actually talk to the server and is this a valid and cheap test.
#    return 1 if $dbh->prepare ("tables");
#    return 0;
#    } # ping

sub STOREx
{
    my ($dbh, $attr, $val) = @_;

    if ($attr eq "AutoCommit") {
#	carp "AutoCommit not supported in DBD::Unify\n"
#	    if $drh->{Warn};
	return 1;
	}
    if ($attr eq "ScanLevel") {
	if ($val =~ m/^\d+$/ && $val >= 1 && $val <= 16) {
	    $dbh->{$attr} = $val;
	    $dbh->do ("set transaction scan level $val");
	    return 1;
	    }
#	carp "ScanLevel $val invalid, use 1 .. 16\n"
#	    if $drh->{Warn};
	return 1;
	}
    $dbh->SUPER::STORE ($attr, $val);
    } # STORE

sub FETCHx
{
    my ($dbh, $attr) = @_;

    $attr eq "AutoCommit"		and return 0;

    # ScanLevel can be changed with $dbh->do (), so this is not very reliable
    $attr eq "ScanLevel"		and return $dbh->{$attr};

    $dbh->SUPER::FETCH ($attr);
    } # FETCH

1;

####### Statement #############################################################

package DBD::Unify::st;

1;

####### End ###################################################################

=head1 DESCRIPTION

DBD::Unify is an extension to Perl which allows access to Unify
databases. It is built on top of the standard DBI extension an
implements the methods that DBI require.

This document describes the differences between the "generic" DBD and
DBD::Unify.

=head2 Extensions/Changes

=over 4

=item returned types

The DBI docs state that:

=over 2

Most data is returned to the perl script as strings (null values are
returned as undef).  This allows arbitrary precision numeric data to be
handled without loss of accuracy.  Be aware that perl may not preserve
the same accuracy when the string is used as a number.

=back

This is B<not> the case for Unify.

Data is returned as it would be to an embedded C program:

=over 2

Integers are returned as integer values (perl's IVs).

(Huge) amounts, floats and doubles are returned as numeric
values (perl's NVs).

Chars are returned as strings (perl's PVs).

Dates, varchars and others are returned as undef (for
the moment).

=back

=item connect

    connect ("DBI:Unify:dbname[;options]" [, user [, auth [, attr]]]);

Options to the connection are passed in the datasource
argument. This argument should contain the database
name possibly followed by a semicolon and the database options
which are ignored.

Since Unify database authorisation is done using grant's using the
user name, the <user> argument me be empty or undef. The auth
field will be used as a default schema. If the auth field is empty
or undefined connect will check for the environment variable $USCHEMA
to use as a default schema. If neither exists, you will end up in your
default schema, or if none is assigned, in the schema PUBLIC.

At the moment none of the attributes documented in DBI's "ATTRIBUTES
COMMON TO ALL HANDLES" are implemented specifically for the Unify
DBD driver, but they might have been inhereted from DBI. The I<ChopBlanks>
attribute is implemented, but defaults to 1 for DBD::Unify.
The Unify driver supports "ScanLevel" to set the transaction scan
level to a value between 1 and 16 and "DBDverbose" to set DBD specific
debugging, allowing to show only massages from DBD-Unify without using
the default DBI->trace () call.

The connect call will result in statements like:

    CONNECT;
    SET CURRENT SCHEMA TO PUBLIC;  -- if auth = "PUBLIC"
    SET TRANSACTION SCAN LEVEL 7;  -- if attr has { ScanLevel => 7 }

=over 4

=item local database

       connect ("/data/db/unify/v63AB", "", "SYS")

=back

and so on.

It is recommended that the C<connect> call ends with the attributes
C<{ AutoCommit => 0 }>, although it is not implemented (yet).

If you dont want to check for errors after B<every> call use 
C<{ AutoCommit => 0, RaiseError => 1 }> instead. This will C<die> with
an error message if any DBI call fails.

=item do

    $dbh->do ($statement)

This is implemented as a call to 'EXECUTE IMMEDIATE' with all the
limitations that this implies.

=item commit and rollback invalidates open cursors

DBD::Unify does warn when a commit or rollback is isssued on a $dbh
with open cursors.

Possibly a commit/rollback should also undef the $sth's. (This should
probably be done in the DBI-layer as other drivers will have the same
problems).

After a commit or rollback the cursors are all ->finish'ed, ie. they
are closed and the DBI/DBD will warn if an attempt is made to fetch
from them.

A future version of DBD::Unify might re-prepare the statement.

=back

=head1 NOTES

Far from complete ...

=head1 SEE ALSO

The DBI documentation in L<DBI>, other DBD documentation.

=head1 AUTHORS

DBI/DBD was developed by Tim Bunce, <Tim.Bunce@ig.co.uk>, who also
developed the DBD::Oracle.

H.Merijn Brand, <h.m.brand@hccnet.nl> developed the DBD::Unify extension.

=cut
