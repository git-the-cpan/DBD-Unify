#!perl -w

print "1..0\n";

exists $ENV{DBD_UNIFY_SKIP_27} or
    print STDERR "\nTo disable future max tests: setenv DBD_UNIFY_SKIP_27 1\n";
