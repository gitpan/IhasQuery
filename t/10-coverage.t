#!perl -T

use strict ;
#use Test::More tests => 6 ;
use Test::More 'no_plan' ;
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
my $prev = '' ;

isnt( $table_stuff->insert( 
            'CLEAR' => 0 ,
            'SETWHERE' => ['word', 'LIKE', 'JUMB%'] , ) , 0 , 'This insert should fail and return a value other than 0' ) ;

isnt( $table_stuff->update( 
            'CLEAR' => 0 ,
            'SETWHERE' => ['word', 'LIKE', 'JUMB%'] , ), 0 , 'This update should fail and return a value other than 0. It may cause a DBD error to appear, due to output buffering this may be later in the output.' ) ;
            
isnt( $table_stuff->update( 
            'CLEAR' => 0 ,
            'FIELDS' => ['NAME'],
            'FIELD_VALUE' => { 'integer' => 1497 , 'word' => 'Columbus' } ,
            'SETWHERE' => ['word', 'LIKE', 'JUMB%'] , ), 0 , 'This update should fail and return a value other than 0' ) ;
my $qcomp = qq /UPDATE stuff SET WHERE "word" LIKE 'JUMB%' ;/ ;
is ($table_stuff->preview(),$qcomp, 'Preview should match expected query.' );

is( $table_stuff->select( 'WHERE' => 'ALL', ), 0, "This should succeed and return 0")  ;

like( $table_haskey->preview('DELETE'), qr/DELETE/, 'A preview of a Delete!' ) ;


