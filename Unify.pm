#   Copyright (c) 1999,2000 H.Merijn Brand
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.

require 5.004;

use strict;

=head1 NAME

DBD::Unify - DBI driver for Unify database systems

=head1 SYNOPSIS

    $dbh = DBI->connect ("DBI:Unify:\$dbname", "", $schema,
			    { AutoCommit => 0 });
    $dbh->do ($statement);
    $dbh->commit ();
    $dbh->rollback ();
    $dbh->disconnect ();

    $sth = $dbh->prepare ($statement)
    $sth->execute ();
    @row = $sth->fetchrow_array ()
    $sth->finish ();
    ...

=cut

# The POD text continues at the end of the file.

###############################################################################

package DBD::Unify;

use DBI 1.12;
use DynaLoader ();

use vars qw(@ISA $VERSION);

@ISA = qw(DynaLoader);

$VERSION = "0.01";

bootstrap DBD::Unify $VERSION;

use vars qw($err $errstr $drh);
$err    = 0;		# holds error code   for DBI::err
$errstr = "";		# holds error string for DBI::errstr
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
	Attribution  => "Unify DBD by H.Merijn Brand",
	});

    $drh;
    } # driver

1;

####### Driver ################################################################

package DBD::Unify::dr;

sub connect
{
    my ($drh, $dbname, $user, $auth) = @_;

    # create a 'blank' dbh
    my $this = DBI::_new_dbh ($drh, {
	Name          => $dbname,
	USER          => $user,
	CURRENT_USER  => $user,
	});

    unless ($ENV{UNIFY}) {
	warn ("UNIFY not set. Unify may fail\n")
	    if $drh->{Warn};
	}
    # More checks here if wanted ...

    $user = "" unless defined $user;
    $auth = "" unless defined $auth;
    
    # Connect to the database..
    DBD::Unify::db::_login ($this, $dbname, $user, $auth)
	or return undef;

    $this;
    } # connect

sub data_sources
{
    my ($drh) = @_;
    warn ("\$drh->data_sources() not defined for Unify\n")
	if $drh->{"warn"};
    "";
    } # data_sources

####### Database ##############################################################

package DBD::Unify::db;

sub do
{
    my ($dbh, $statement, $attribs, @params) = @_;
    Carp::carp "DBD::Unify::\$dbh->do () attribs unused\n" if $attribs;
    Carp::carp "DBD::Unify::\$dbh->do () params unused\n"  if @params;
    DBD::Unify::db::_do ($dbh, $statement);
    } # do

sub prepare
{
    my ($dbh, $statement, $attribs) = @_;

    # create a 'blank' sth
    my $sth = DBI::_new_sth ($dbh, {
	uni_statement => $statement
	});

    DBD::Unify::st::_prepare ($sth, $statement, $attribs)
	or return undef;

    $sth;
    } # prepare

sub table_info
{
    my ($dbh) = @_;
    my $sth = $dbh->prepare ("select * from SYS.ACCESSIBLE_TABLES");
    return unless $sth;
    $sth->execute ();
    $sth;
    } # table_info

sub ping
{
    my ($dbh) = @_;
    # we know that DBD::Unify prepare does a describe so this will
    # actually talk to the server and is this a valid and cheap test.
    return 1 if $dbh->prepare ("tables");
    return 0;
    } # ping

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

    connect ("DBI:Unify:dbname[;options]" [, user [, password]]);

Options to the connection are passed in the datasource
argument. This argument should contain the database
name possibly followed by a semicolon and the database options
which are ignored.

Since Unify database authorisation is done using grant's using the
user name, the <user> argument me be empty or undef. The password
field will be used as a default schema. If the password field is empty
or undefined connect will check for the environment variable $USCHEMA
to use as a default schema. If neither exists, you will end up in your
default schema, or if none is assigned, in the schema PUBLIC.

The connect call will result in a connect statement like:

    CONNECT;
    SET CURRENT SCHEMA TO password;

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

A future version of DBD::Unify wil possibly re-prepare the statement.

=back

=head1 NOTES

Far from complete ...

=head1 SEE ALSO

The DBI documentation in L<DBI>, other DBD documentation.

=head1 AUTHORS

DBI/DBD was developed by Tim Bunce, <Tim.Bunce@ig.co.uk>, who also
developed the DBD::Oracle that is the closest we have to a generic DBD
implementation.

H.Merijn Brand, <h.m.brand@hccnet.nl> developed the DBD::Unify extension.

=cut
