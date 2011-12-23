#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'SQL::Maker::DBICLike' ) || print "Bail out!\n";
}

diag( "Testing SQL::Maker::DBICLike $SQL::Maker::DBICLike::VERSION, Perl $], $^X" );
