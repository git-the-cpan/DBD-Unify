#!/usr/local/bin/perl -w

require 5.004;

use strict;

use ExtUtils::MakeMaker;

use DBI 1.13;
use DBI::DBD;

print "\nConfiguring DBD::Unify ...\n\n";

$^O =~ m/^(?: VMS | MsWin32 | cygwin )$/x and
    die "OS type $^O is not (yet) supported";

use vars qw($UNIFY $UNITOP $ULIBS);
CheckUnify ();

WriteMakefile (
    NAME          =>   "DBD::Unify",
    DISTNAME      =>   "DBD-Unify",
    VERSION_FROM  =>   "Unify.pm",
    AUTHOR        =>   "H.Merijn Brand <h.m.brand\@hccnet.nl>",
    ABSTRACT_FROM =>   "Unify.pm",

    PREREQ_PM     => { DBI      => "1.13",
		       },

    dist          => { COMPRESS => "gzip -9f",
		       SUFFIX   => ".gz",
		       },

    clean         => { FILES => "dbdimp.c dbdimp.ec Unify.ec",
		       },
    realclean     => { FILES => "Unify.xsi ulib",
		       },

    LINKTYPE      =>   "dynamic",
    INC           =>   "-I$UNITOP -I$UNITOP/include -I\$(DBI_INSTARCH_DIR)",
    OBJECT        =>   "Unify\$(OBJ_EXT) dbdimp\$(OBJ_EXT)",

    depend        => { "dbdimp\$(OBJ_EXT)" => "dbdimp.c Unify.h",
		       "Unify\$(OBJ_EXT)"  => "Unify.h",
		       },

    dynamic_lib   => { OTHERLDFLAGS => " $ULIBS \$(COMPOBJS) " .
					    { hpux	=> "",
					      aix	=> "-lm",
					      dec_osf	=> "-lxnet",
					      }->{$^O},
		       },
    macro         => { EPP    => "$UNITOP/bin/EPP",
		       EPPOPT => "",
		       CC     => ($^O eq "aix" ? "env UPPNAME='cc -E' " : "")
		       			. "$UNITOP/bin/ucc",
		       },
    );

sub CheckUnify
{
    exists $ENV{UNIFY}	or die "\$UNIFY not set";
    exists $ENV{DBPATH}	or die "\$DBPATH not set";

    $UNIFY  = $ENV{UNIFY};

    -d $UNIFY		or die "\$UNIFY is not a valid directory";
    -d $ENV{DBPATH}	or die "\$DBPATH is not a valid directory";

    $UNITOP = $UNIFY;
    { chomp (my $cwd = `pwd`);
      chdir $UNIFY	or die "\$UNIFY cannot be accessed: $!";
      chomp ($UNIFY  = `pwd`);	# Remove symlinks and relatives like /../
      chdir "..";
      chomp ($UNITOP = `pwd`);
      chdir $cwd;
      }

    unlink "ulib";
    symlink $UNIFY, "./ulib";
    # Checked for A/SQL DS 6.3 AB & 8.1CC
    my @ulibs = qw(
	ACCELL.a
	S2000e.a S2000c.a
	U2000c.a U2000u.a U2000k.a
	U2000c.a
	S2000u.a S2000c.a U2000r.a
	libnwrpc.a libnwstcp.a
	U2000c.a U2000u.a);
    print "Do you *need* networked databases? [y/N] > N\b";
    scalar <STDIN> =~ m/^\s*[yYjJ]/ or
	@ulibs = map { s/0u\.a/0ul.a/; $_ } grep m/[ASU]/, @ulibs;
    $ULIBS = join " ulib/" => "", @ulibs;
    print "\n";

    # --- Check development environment

    sub Check ($)
    {
	my $f = shift;
	-r "$UNITOP/$f" && -s _ && (-x _ || $f !~ m/^bin/) and return;
	die "I can't find $f\n".
	    "Is your Unify set up correctly??\n";
	} # Check
    Check ("bin/SQL");
    Check ("bin/EPP");
    map { Check ($_) } split m/ u/ => $ULIBS;

    my @sqlv = `SQL -version`;
    splice @sqlv, -2, 2;
    print "System:           perl$] $^O\n",
	  "UNIFY:            $UNITOP\n",
	  @sqlv,
	  "\n";

    $UNITOP;
    } # CheckUnify

package MY;

sub postamble
{
    join "\n" =>
	DBI::DBD::dbd_postamble (),
	'',
	'dbdimp.c:		dbdimp.ec Unify.h',
	'	$(EPP) $(EPPOPT) dbdimp.ec ',
	'',
	'dbdimp.ec:		dbdimp.ic',
	'	$(PERL) ic2ec dbdimp.ic > dbdimp.ec',
	'',
	'installu uinstall:	all',
	'	$(PERL) installu.pl',
	'';
    } # postamble

sub libscan
{
    my ($self, $path) = @_;
    ($path =~ m/\~$/) ? undef : $path;
    } # libscan

1;
