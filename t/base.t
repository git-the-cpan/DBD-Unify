#!perl -w

# Base DBD Driver Test

BEGIN { $tests = 5 }

print "1..$tests\n";

require DBI;
print "ok 1\n";

import DBI;
print "ok 2\n";

$switch = DBI->internal;
(ref $switch eq 'DBI::dr') ? print "ok 3\n" : print "not ok 3\n";

eval {
    # This is a special case. install_driver should not normally be used.
    $drh = DBI->install_driver ('Unify');
    (ref $drh eq 'DBI::dr') ? print "ok 4\n" : print "not ok 4\n";
    };
if ($@) {
    $@ =~ s/\n\n+/\n/g if $@;
    warn "Failed to load Unify extension and/or shared libraries:\n$@" if $@;
    warn "The remaining tests will probably also fail with the same error.\a\n\n";
    # try to provide some useful pointers for some cases
    warn "*** Please read the README and README.help files for help. ***\n";
    warn "\n";
    sleep 5;
    }

print "ok 5\n" if $drh->{Version};

exit 0;
