# Uniperl emulation interface for DBD::Unify
#
# Written by H.Merijn Brand <h.m.brand@hccnet.nl>
#

use DBD::Unify;

package Uniperl;
use DBI 1.03;
use Exporter;
use Carp;

$VERSION = 0.01;

@ISA = qw(Exporter);

@EXPORT = qw(
    &sql &sql_exec &sql_fetch &sql_close
    &sql_types &sql_ingtypes &sql_lengths &sql_nullable &sql_names
    $sql_version $sql_error $sql_sqlcode $sql_rowcount $sql_readonly
    $sql_showerrors $sql_debug
    &sql_eval_row1 &sql_eval_col1
    );

@EXPORT_OK = qw(
    $sql_drh $sql_dbh $sql_sth
    );

use strict;
use vars qw($sql_drh $sql_dbh $sql_sth $sql_debug $sql_rowcount);

defined $sql_debug or $sql_debug = 0;

if ($sql_debug) {
    my $sw = DBI->internal;
    print "Switch: $sw->{Attribution}, $sw->{Version}\n";
    }

# Install Driver
$sql_drh = DBI->install_driver ('Unify');
if ($sql_drh) {
    print "DBD::Unify driver installed as $sql_drh\n" if $sql_debug;
    $sql_drh->{Warn}       = 0;
    $sql_drh->{CompatMode} = 1;
    }

### ###########################################################################

# &sql_exec
# &sql_fetch ()
# &sql ()

sub sql_exec
{
    my ($statement) = @_;
    # decide what this is...
    warn "sql_exec ('$statement')\n" if $sql_debug;
    if ($statement =~ m/^\s*connect\b/i) {
        # connect to the database;
        croak "Already connected to database, at" if $sql_dbh;
        my ($database, $user, $option);
        # this contain the database name and possibly a username
        # find database
        ($database) = $statement =~ m!connect\s+([\w:/]+)!i;
        my $rest = $';  #possibly contains username... and other options
        if ($rest =~ m/identified\s+by\s+(\w+)/i) {
            $user = $1;
            $option = "$` $'"; # every thing else..
	    }
	elsif ($rest =~ m/-u(\w+)/) {
            $user = $1;
            $option = "$` $'"; # every thing else..
	    }
	else {
            $user = ""; # noone;
            $option = $rest
	    }
        warn "Uniperl connecting to database '$database' as user '$user'\n"
            if $sql_debug;
	$option =~ s/^\s+//;
        $sql_dbh = $Uniperl::sql_drh->connect ("$database;$option", $user);
	}
    else {
        croak "Uniperl: Not connected to database, at" unless $sql_dbh;

	$sql_rowcount = 0;
	if ($statement =~ m/^\s*disconnect\b/i) {
            $sql_dbh->disconnect ();
            undef $sql_dbh;
	    }
    	elsif ($statement =~ m/^\s*commit\b/i) {
            $sql_dbh->commit ();
	    }
	elsif ($statement =~ m/^\s*rollback\b/i) {
            $sql_dbh->rollback ();
	    }
        else {
            # This is something else. Just execute the statement
            $sql_rowcount = $sql_dbh->do ($statement);
	    }
	}
    } # sql_exec

sub sql_close
{
    if ($sql_sth) {
        $sql_sth->finish;
        undef $sql_sth;
	}
    else {
        carp "Uniperl: close with no open cursor, at"
            if $sql_drh->{Warn};
	}
    1;
    } # sql_close

sub sql_fetch
{
    croak "Uniperl: No active cursor, at" unless $sql_sth;
    my (@row) = $sql_sth->fetchrow ();
    $sql_rowcount = $sql_sth->rows ();
    unless (@row) {
	&sql_close ();
	return wantarray ? () : undef;
	}
    if (wantarray) {
        return @row;
	}
    # wants a scalar
    carp "Multi-column row retrieved in scalar context, at"
	if $sql_sth->{Warn};
    return $sql_sth->{CompatMode} ? $row[0] : @row;
    } # sql_fetch

sub sql
{
    my ($statement) = @_;
    if ($statement =~ m/^\s*fetch\b/i) {
        return &sql_fetch ();
	}
    elsif ($statement =~ m/^\s*select\b/i) {
        if ($sql_sth) {
            warn "Uniperl: Select while another select active - closing".
            	" previous select, at"
                    if $sql_debug or $sql_sth->{Warn};
            $sql_sth->finish ();
            undef $sql_sth;
	    }
        $sql_sth = $sql_dbh->prepare ($statement) or return undef;
        undef $sql_rowcount;
        $sql_sth->execute() or return undef;
	}
    else {
        return &sql_exec ($statement);
	}
    } # sql

### ###########################################################################

# @types    = &sql_types;
# @ingtypes = &sql_ingtypes;
# @lengths  = &sql_lengths;
# @nullable = &sql_nullable;
# @names    = &sql_names;

sub sql_types       { $sql_sth ? @{$sql_sth->{uni_types}}   : undef; }
sub sql_unitypes    { $sql_sth ? @{$sql_sth->{uni_unitypes}}: undef; }
sub sql_lengths     { $sql_sth ? @{$sql_sth->{uni_lengths}} : undef; }
sub sql_nullable    { $sql_sth ? @{$sql_sth->{NULLABLE}}    : undef; }
sub sql_names       { $sql_sth ? @{$sql_sth->{NAME}}        : undef; }

### ###########################################################################

tie $Uniperl::sql_version,    "Uniperl::var", "version";
*sql_error   = \$DBD::Unify::errstr;
*sql_sqlcode = \$DBD::Unify::err;
# *sql_rowcount = \$DBI::rows;
tie $Uniperl::sql_readonly,   "Uniperl::var", "readonly";
tie $Uniperl::sql_showerrors, "Uniperl::var", "showerror";

### ###########################################################################

# Library function to execute a select and return first row
sub sql_eval_row1
{
    my $sth = $sql_dbh->prepare (@_);
    return undef unless $sth;
    $sth->execute or return undef;
    my @row = $sth->fetchrow;	# fetch one row
    $sth->finish;		# close the cursor
    undef $sth;
    @row;
    } # sql_eval_row1

# Library function to execute a select and return first col
sub sql_eval_col1
{
    my $sth = $sql_dbh->prepare (@_);
    return undef unless $sth;
    $sth->execute or return undef;
    my ($row, @col);
    while ($row = $sth->fetch) {
	push @col, $row->[0];
	}
    $sth->finish;		# close the cursor
    undef $sth;
    @col;
    } # sql_eval_col1

### ###########################################################################

package Uniperl::var;
use Carp qw(carp croak confess);
use strict;

sub TIESCALAR
{
    my ($class, $var) = @_;
    return bless \$var, $class;
    } # TIESCALAR

sub FETCH
{
    my $self = shift;
    confess "wrong type" unless ref $self;
    croak "too many arguments" if @_;
    if ($$self eq "version") {
        my $sw = DBI->internal;
        "\nIngperl emulation interface version $Uniperl::VERSION\n" .
        "Unify driver $Uniperl::sql_drh->{Version}, ".
        "$Uniperl::sql_drh->{'Attribution'}\n" .
        $sw->{Attribution}. ", ".
        "version " . $sw->{Version}. "\n\n";
	}
    elsif ($$self eq "readonly") {
    	1;   # Not implemented (yet)
	}
    elsif ($$self eq "showerror") {
    	$Uniperl::sql_dbh->{printerror} if defined $Uniperl::sql_dbh;
	}
    else {
        carp "unknown special variable $$self";
	}
    } # FETCH

sub STORE
{
    my $self  = shift;
    my $value = shift;
    confess "wrong type" unless ref $self;
    croak "too many arguments" if @_;
    if ($$self eq "showerror") {
    	$Uniperl::sql_dbh->{printerror} = $value;
	}
    else {
        carp "Can't modify ${$self} special variable, at"
	}
    } # STORE

1;
