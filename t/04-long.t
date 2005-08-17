#!/usr/bin/perl

use strict;
use warnings;

use Test::More skip_all => "DBD::Unify does not (yet) support binary/text";

# Since DBD-Unify does not (yet) support binary/text, there's nothing to test
