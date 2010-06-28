#!perl -T

use strict ;
use Test::More tests => 28 ;
use DBI ;
use File::Copy ;

#use feature ":5.10" ;

use IhasQuery ;

diag( "Testing IhasQuery $IhasQuery::VERSION, Perl $], $^X" );

# This Set of tests were developed to improve coverage.

open my $DB, '<t/dbconfig.dbi' ;
my %db = () ;
WHILEDB: while ( my $line = <$DB> ) {  
        if ( $line =~ m/#/ ) { next WHILEDB } ;
        $line =~ tr/\r\n//d ; # Chomp has never been trustworthy on Windows.
        my ( $itm, $str ) = split /\=/, $line ; 
        $db{ $itm } = $str ; 
        }
close $DB ;
foreach my $k ( keys  %db ) { print " $k $db{ $k }\n" }

my $dbh = DBI->connect( $db{'dbistr'}, $db{'dbiusr'}, $db{'dbipas'} ) or die "Error $DBI::err [$DBI::errstr]" ;
my $table_stuff = IhasQuery->new( $dbh , 'stuff' ) ;
my $table_haskey = IhasQuery->new( $dbh , 'haskey' ) ;


is ( $table_stuff->select( 'WHERE' => "\"word\" = \'JUMBO\'" ) , 0 , 'Select word =JUMBO' ) ;
is ( $table_stuff->count(), 0, 'Jumbo should count 0' ) ;
is ( $table_stuff->select( 'CLEAR' => 7 ) , 0 , 'clear last where clause' ) ;
is ( $table_stuff->count_all(), 2, 'Should now count 2 to confirm' ) ;
is ( $table_stuff->select( 'WHERE' => "\"word\" = \'JUMBO\'" ) , 0 , 'Select word =JUMBO' ) ;
is ( $table_stuff->count( 'WHERE' => "\"word\" = \'JUMBO\'" ), 0, 'Jumbo should count 0' ) ;
is ( $table_stuff->count( 'WHERE' => 'ALL' ), 2, 'Should clear where clause and count 2 ' ) ;

is ( $table_stuff->select(  'CLEAR' => 2  ) , 0 , 'Select All' ) ;
is(  $table_stuff->last_row() , 0 , 'There should be several rows so last_row() should be 0' ) ;
until ( $table_stuff->last_row() ) {
	my %data = $table_stuff->fetchrow_hash()  ;
	if ( $table_stuff->last_row() ) { next } 
	}
is(  $table_stuff->last_row() , 1 , 'Last row should be 1.' ) ;

# Add to the Database.

$table_stuff->insert( 'FIELD_VALUE' => { 'integer' => 166171 , 'word' => 'Sprocket' } , ) ;
$table_stuff->insert( 'FIELD_VALUE' => { 'integer' => 923420 , 'word' => 'AMD' } , ) ;  
my %thash = ( 'integer' => 8922 , 'word' => 'complicated' ) ;
$table_stuff->insert( 'FIELD_VALUE' => \%thash , ) ;  
is ( $table_stuff->count(), 5, 'Should now count 5' ) ;

$table_haskey->insert( 'FIELD_VALUE' => { 'anumber'=> 217, 'aword' => 'Dumbo'  } , ) ;
%thash = ( 'anumber' => 8922 , 'aword' => 'implicated' ) ;
$table_haskey->insert( 'FIELD_VALUE' => \%thash , ) ;  
$table_haskey->insert( 'FIELD_VALUE' => { 'aword' => 'Mambo' , 'anumber'=> 8742 } , ) ;
%thash = ( 'anumber' => 7126 , 'aword' => 'Cleveland' ) ;
$table_haskey->insert( 'FIELD_VALUE' => \%thash , ) ;  
is ( $table_haskey->count(), 6, 'haskey Should now count 6' ) ;

is( $table_haskey->select( 'SETWHERE' => [ 'aword', '=', 'Cleveland' ], 'CLEAR' => 1 ), 0 , 'Trying to fetch Cleveland' ) ;
my @row = $table_haskey->fetchrow() ;
my $row = "@row" ;
like( $row, qr/Cleveland/, 'Cleveland is in the row returned.' ) ;
is( $table_haskey->fetchrow(), 1, 'Fetching another row should return 1 because it is the last row returned') ;
is( $table_haskey->last_row(), 1, 'last_row should also return 1') ;
is( $table_haskey->count( 'SETWHERE' => [ 'aword', '=', 'Cleveland' ], ), 1, 'There is one Cleveland Record' );
is( $table_haskey->delete( 'SETWHERE' => [ 'aword', '=', 'Cleveland' ], 'CLEAR' => 1 ), 0, 'Try to delete Cleveland' ) ;
is( $table_haskey->count( 'SETWHERE' => [ 'aword', '=', 'Cleveland' ], ), 0, 'It is gone' );       

$table_haskey->insert( 'FIELD_VALUE' => { 'aword' => 'Cleveland' , 'anumber'=> 742 } , ) ;
$table_haskey->insert( 'FIELD_VALUE' => { 'aword' => 'Cleveland' , 'anumber'=> 2942 } , ) ;
$table_haskey->insert( 'FIELD_VALUE' => { 'aword' => 'Cleveland' , 'anumber'=> 421 } , ) ;

my $cc = 0;   
my $addum = 742 + 2942 + 421 ;
$table_haskey->clear ;

# The next query is being set by the accessor methods, checked with previewSelect
$table_haskey->where( "\"aword\" = \'Cleveland\'" ) ;
my $prev = qq |SELECT * FROM haskey WHERE "aword" = 'Cleveland' ;| ;

is( $table_haskey->preview('SELECT'), $prev, 'Testing that preview generates the query that has been setup') ;

$table_haskey->select() ;
until ( $table_haskey->last_row() == 1 ) {
        my %data = $table_haskey->fetchrow_hash()  ;
        if ( $table_haskey->last_row() ) { next } ;
        $cc++ ;
        $addum = $addum - $data{ 'anumber' } ;
        }
is( $cc, 3, 'Should count 3 records' ) ;
is( $addum, 0, 'Subtracting the records should get back to 0' ) ;

# Test the query methods.

my $q = qq |SELECT  "key_field", "aword"  FROM haskey WHERE key_field < 3 ;| ;
is( $table_haskey->query( $q ), 0, 'Successfully execute via query method.' ) ;
$cc = 0;
until ( $table_haskey->last_row() == 1 ) {
        my @data = $table_haskey->fetchrow()  ;
        if ( $table_haskey->last_row() ) { next } ;
        $cc++ ;
        }
is( $cc, 2, 'The direct query should have returned 2 items' ) ;

like( $table_haskey->update( 'FIELD_VALUE' => { 'aword' => 'Akron' } ), 
        qr/FAILED/, 'Update missing a where clause should fail.' ) ;
is($table_haskey->update( 
                'FIELD_VALUE' => { 'aword' => 'Akron' } , 
                'SETWHERE' => [ 'anumber', '=', 421 ], )
                , 0 , 'Attempt a properly formed update' ) ;
is($table_haskey->count( 'SETWHERE' => [ 'aword', '=', 'Akron' ], ), 1, 'There is now 1 record for Akron' ) ;

# We are testing with SQLite, which doesn't tell us that we couldn't delete the record.
# All the Cleveland records get deleted and then we do a select and fetchrow to test some conditions.
$table_haskey->delete( 'SETWHERE' => [ 'aword', '=', 'Cleveland' ], );
$table_haskey->select( 'SETWHERE' => [ 'aword', '=', 'Cleveland' ], );
ok( $table_haskey->fetchrow() != 0 , 'Failed to fetch a row, should not return 0' );

