#!/usr/local/bin/perl -sw

require 5.004;

use ExtUtils::MakeMaker;
use Config;
use strict;

# This DBI must be installed before we can build a DBD.
# For those not using Dynamic loading this means building a
# new static perl in the DBI directory by saying 'make perl'
# and then using _that_ perl to make this one.
use DBI;
use DBI::DBD;

$^O eq "VMS" || $^O eq "MSWin32" and
    die "OS type $^O is not (yet) supported";

my %opts = (
    PREREQ_PM    => { "DBI"	=> "0.93"	},
    NAME         =>   "DBD::Unify",
    DISTNAME     =>   "DBD-Unify",
    VERSION_FROM =>   "Unify.pm",
    dist         => {
	COMPRESS     => "gzip -9f",
	SUFFIX       => ".gz",
	},
    LINKTYPE     => "dynamic",
    OPTIMIZE     => "-O",
    ($] >= 5.005)
	? ( AUTHOR        => "H.Merijn Brand <h.m.brand\@hccnet.nl>",
	    ABSTRACT_FROM => "Unify.pm",
	    )
	: (),
    );

# --- Introduction

print "\nConfiguring DBD::Unify ...\n\n";

# --- Where is UNIFY installed...

-d $ENV{UNIFY} or
    die "\$II_SYSTEM not defined. No Unify?\n";
my $UNIFY = $ENV{UNIFY};
my $UNIHOME = $UNIFY;
{ chomp (my $cwd = `pwd`);
  chdir $UNIFY or die "$UNIFY is not a valid UNIFY directory";
  chomp ($UNIFY   = `pwd`);	# Remove symlinks and relatives like /../
  chdir "..";
  chomp ($UNIHOME = `pwd`);
  chdir $cwd;
  }

print "Using Unify in $UNIHOME\n";

unlink "ulib";
symlink $UNIFY, "./ulib";
my $unilibs = join " ulib/" => "",
    qw(ACCELL.a
       S2000e.a S2000c.a
       U2000c.a U2000u.a U2000k.a
       U2000c.a
       S2000u.a S2000c.a U2000r.a
       libnwrpc.a libnwstcp.a
       U2000c.a U2000u.a);

# --- Handle special cases ---

#$opts{DEFINE} = "-Wall -pedantic -Wno-comment -Wtraditional"
#    if $Config{cc} eq "gcc";

print "I can't find your Unify precompiler (EPP)\n",
      "Is your Unify set up correctly??\n"
    unless -x "$UNIHOME/bin/EPP";

if ($Config{osname} eq "hpux") {
#   print "Warning: forced to build static not dynamic on $Config{osname} $Config{osvers}\n";
#   print "         See README for more information.\n";
#   $opts{LINKTYPE} = "static";
    }

# log key platform information to help me help you quickly
my @sqlv = `SQL -version`;
splice @sqlv, -2, 2;
print "System:           perl$] @Config{qw(myuname)}\n",
      "Compiler:         @Config{qw(cc optimize ccflags)}\n",
      "UNIFY:            $UNIFY\n",
      @sqlv;

print "\n";

# compute path to DBI include files
my $INSTALLSITEARCH = $INC{"DBI.pm"};
$INSTALLSITEARCH =~ s(/DBI.pm$)();
my $DBIXS_INSTALL_DIR;
foreach my $guess ("$INSTALLSITEARCH/" . $Config::Config{archname},
		$Config::Config{installsitearch}) {
    if (-f "$guess/auto/DBI/DBIXS.h") {
        $DBIXS_INSTALL_DIR = "$guess/auto/DBI";
        $opts{INC} = "-I$DBIXS_INSTALL_DIR";
        last;
	}
    }
if (!$DBIXS_INSTALL_DIR) {
    die "Unable to find header file DBIXS.h; you seem to have an"
	. " interesting Perl setup ...\n";
    }

$opts{dynamic_lib} = { OTHERLDFLAGS => " $unilibs \$(COMPOBJS)" };
$opts{OBJECT} = 'Unify$(OBJ_EXT) dbdimp$(OBJ_EXT)';
$opts{depend} = { "dbdimp\$(OBJ_EXT)" => "dbdimp.c Unify.h",
		  "Unify\$(OBJ_EXT)"  => "Unify.h",
		  };
$opts{clean} = { FILES	=> "dbdimp.c dbdimp.ec Unify.ec Unify.xsi ulib" };
$opts{macro} = { EPP	=> "$UNIHOME/bin/EPP",
		 EPPOPT	=> "",
		 CC	=> "$UNIHOME/bin/ucc",
		 INC	=> "-I$UNIHOME -I$UNIHOME/include -I$DBIXS_INSTALL_DIR",
		 };
WriteMakefile (%opts);

exit 0;

sub MY::post_initialize
{
    my $self = shift;
    # Ensure Uniperl.pm is installed into top lib dir
    $self->{PM}->{"Uniperl.pm"} = '$(INST_LIB)/Uniperl.pm';
    
    "";
    } # MY::post_initialize

sub MY::postamble
{
    my $driver_xst_path = $DBIXS_INSTALL_DIR."/Driver.xst";

    q[
dbdimp.c:		dbdimp.ec Unify.h
	$(EPP) $(EPPOPT) dbdimp.ec 

dbdimp.ec:		dbdimp.ic
	$(PERL) ic2ec dbdimp.ic > dbdimp.ec

$(BASEEXT).xs: $(BASEEXT).xsi].q[

$(BASEEXT).c: $(BASEEXT).xsi

DBI_DRIVER_XST = ].$driver_xst_path.q[

$(BASEEXT).xsi: $(DBI_DRIVER_XST)
	$(PERL) -p -e "s/~DRIVER~/$(BASEEXT)/g" <$(DBI_DRIVER_XST) >$(BASEEXT).xsi
];
    } # MY::postamble

1;

__END__
