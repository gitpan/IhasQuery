#!perl -T

use Test::More tests => 2;
use DBI ;
use File::Copy ;


BEGIN {
    use_ok( 'IhasQuery' ) || print "Bail out!
";
}

diag( "Testing IhasQuery $IhasQuery::VERSION, Perl $], $^X" );

unlink 'testdb1.db'  ; 
copy('testdb1.start','testdb1.db') or die "Copy failed: $!";
ok( stat 'testdb1.db' , 'There is a test database' ) ;



