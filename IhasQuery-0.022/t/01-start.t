#!perl -T

use strict ;
use Test::More tests => 30 ;
use DBI ;
use File::Copy ;

#use feature ":5.10" ;

use IhasQuery ;

diag( "Testing IhasQuery $IhasQuery::VERSION, Perl $], $^X" );

# This Set of tests performs some very simple operations.
# the next 

# This code section belongs in 00, but creates problems if 00 is not executed immediately before 01.
unlink 'testdb1.db'  ; 
copy('testdb1.start','testdb1.db') or die "Copy failed: $!";
ok( stat 'testdb1.db' , 'There is a test database' ) ;
# End Note.

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

#exit ;
my $dbh = DBI->connect( $db{'dbistr'}, $db{'dbiusr'}, $db{'dbipas'} ) or die "Error $DBI::err [$DBI::errstr]" ;
#my $dbh = DBI->connect( 'dbi:SQLite:testdb1.db', , , ) or die "Error $DBI::err [$DBI::errstr]" ;

ok( defined $dbh , , 'DBI returned an object' ) ;
ok( defined $dbh->state , 'DBI state' ) ;

my $table_haskey = IhasQuery->new( $dbh , 'haskey' ) ;
ok( defined $table_haskey, 'IhasQuery made a new object' );                # check that we got something
ok( $table_haskey->isa('IhasQuery') , 'That object is an IhasQuery' );     # and it's the right class
ok( $table_haskey->{'TABLE'} eq 'haskey' , 'Object is internally referring to correct table.' ) ;
my $table_stuff = IhasQuery->new( $dbh , 'stuff' ) ;


# where
my $teststr = qq / "aword" = 'smaller' / ;
$table_haskey->where( $teststr ) ;
ok( $teststr eq $table_haskey->{'WHERE'} , 'where set the where value correctly' ) ;
# setwhere
$table_haskey->setwhere( 'aword', '=', 'excellent' ) ;
$teststr = qq / "aword" = 'excellent' / ;
ok( $teststr eq $table_haskey->{'WHERE'} , '8 setwhere set the where value correctly' ) ;

ok( $table_haskey->count() == 1 , 'Test that our testwhere finds only 1 record this means hitting the db!' ) ;

# Prove that field_values() stores the hash and the sets the keys to FIELDS.
$table_stuff->{'FIELDS'} = [] ; # make sure fields is an empty array reference.
ok( scalar( @{$table_stuff->{'FIELDS'}} ) == 0 , 'Test that FIELDS is empty.' ) ;
$table_stuff->field_values( 'integer' => 747 , 'word' => 'Jumbo Jet' ) ;
ok( scalar( @{$table_stuff->{'FIELDS'}} ) == 2 , 'Test that method field_vlaues put two elements in FIELDS.' ) ;
my @ar1 = @{$table_stuff->{'FIELDS'}} ; 
my @ar2 = $table_stuff->fields() ;
ok( $ar1[1] eq $ar2[1] , 'Test that the fields method is returning the internal array correctly, does item match?' ) ;
ok( @ar1 == @ar2 , 'And that the number of elements is the same.' ) ;
$table_stuff->insert() ; 
ok( $table_stuff->last_error() eq 0 , 'Inserted the values we put into the object' );

$table_haskey->clear() ;
ok ( $table_haskey->where() eq undef , 'method clear should have cleared WHERE that was previously set.' ) ;
$table_stuff->clear() ;
ok ( @{$table_haskey->{'FIELDS'}} < 1 , 'method clear should have cleared FIELDS that were previously set.' ) ;

my $prev = $table_haskey->insert( 
            'FIELD_VALUE' => { 'key_field' => 2 , 'aword' => 'Jumbo Jet' , 'anumber'=> 6 } ,
            ) ;
like( $prev , qr/failed/, 'Attempting to insert duplicate record to table with unique constraint should fail' ) ;
like( $table_haskey->last_error(), qr/failed/, 'Confirm the failure via last_error method.' ) ;


$prev = $table_stuff->insert( 
            'FIELD_VALUE' => { 'integer' => 1497 , 'word' => 'Columbus' } ,
            ) ;
$prev = $table_haskey->select( 
            'SETWHERE' => [ 'aword' , '=', 'excellent' ] ,
            ) ; 
                       
ok( $prev eq 0 , 'A successful select should return 0' ) ;
my %RESULT = $table_haskey->fetchrow_hash() ;
ok( $RESULT{ 'aword' } eq 'excellent' , "Check for expected value in returned hash" ) ;

$prev = $table_stuff->select( 
            'SETWHERE' => [ 'word' , '=', 'Jumbo Jet' ] ,
            ) ;
            


ok( $prev == 0 , 'A successful select should return 0' ) ;
%RESULT = $table_stuff->fetchrow_hash() ;
ok( $RESULT{ 'integer' } == 747 , "Check for expected value 747 in returned hash" ) ;
ok( $RESULT{ 'word' } eq 'Jumbo Jet' , "Check for expected value Jumbo Jet in returned hash" ) ;



# SQLITE doesn't take the multiline form of insert, I was going to insert a few records.
my $insert =            qq /INSERT INTO stuff ( "integer", "word" ) 
                        VALUES ( 2061, 'Slow Dive' ) ; / ;
                        
is( $table_stuff->query( $insert ), 0 , 'Insert should succeed via the ->QUERY method' ) ;
ok( $table_stuff->count( 'WHERE' => 'ALL' ) == 3 , 'Check that there are the right number of items in DB' ) ;

$table_stuff->where( 'This is a bad string for a where clause' ) ;
ok( $table_stuff->count_all( ) == 3 , 'Check that count_all agrees, after setting a spurious where clause.' ) ;

$prev = qq |"integer" = 2061 ;| ;
is( $table_stuff->delete( 'WHERE' => $prev ), 0 , 'Confirm a deletion' ) ;

$prev = $table_stuff->update( 
            'CLEAR' => 0 ,
            'SETWHERE' => ['word', 'LIKE', 'JUMB%'] ,
            'FIELD_VALUE' => { 'integer' => 777 } , ) ;
           
my %inserttohaskey = (  'aword' => 'Flying Boat' , 'anumber'=> 622 ) ; #
$prev = $table_haskey->insert(
            'FIELD_VALUE' => \%inserttohaskey ) ;
is( $prev, 0 , 'inserted using a hashreference to the values' ) ;
ok( $table_haskey->count( 'SETWHERE' => [ 'aword', '=', 'Flying Boat' ] ) == 1 , '1 flying boat in the table' ) ;
$table_haskey->delete( 'SETWHERE' => [ 'aword', '=', 'Flying Boat' ] ) ;
ok( $table_haskey->count( 'SETWHERE' => [ 'aword', '=', 'Flying Boat' ] ) == 0 , ' flying boat has been deleted.' ) ;
