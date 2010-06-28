package IhasQuery;

#use warnings;
use strict;
use DBI ;
use feature ":5.10" ;

our $VERSION = '0.022';

=head1 IhasQuery: A simple Object Oriented Wrapper for DBI.

Version 0.022

=cut


sub new  { 
	my $class = shift ;
	my $dbh = shift ;
	my $table = shift ;
	my $dbtype = shift ; # Currently the only meaningful value is 'pg'. 
	my $self->{'NAME'} = $table ;
	$self->{'TABLE'} = $table ;
	$self->{'DBH'} = $dbh ;	
	$self->{'ACTION'} = '' ;
	$self->{'STORED_PROCEDURE'} = '' ;
	$self->{'WHERE'} = undef ;
	$self->{'FLAG'} = '' ;
	$self->{'GROUPBY' } = '' ;
	$self->{'ORDERBY' } = '' ;	
	$self->{'QH'} = undef ;
	$self->{'LASTERR'} = 0 ; # An error is a string, but no error returns 0.
	$self->{'LASTROW'} = 0 ;
	$self->{'FIELDS'} = [] ;
	$self->{'FIELD_VALUE'} = {} ;	
	bless $self, $class ;
	return $self ;
}

sub clear {
	my $self = shift ;
	$self->{'FLAG'} = '' ;
	$self->{'GROUPBY' } = '' ;
	$self->{'ORDERBY' } = '' ;
	$self->{'WHERE'} = undef ;
	$self->{'FIELDS'} = [] ;
	$self->{'FIELD_VALUE'} = {} ;
	$self->{'QH'} = undef ;
	$self->{'LASTERR'} = 0 ;
	$self->{'LASTROW'} = 0 ;
}
	
sub __write_query__ {
	my $self = shift ; 
	my $whereclause =  '' ;
	# FIELD_VALUE and FIELDS get copied to regular arrays/hashes for 
	# programming convenience and readability.
	my %FIELD_VALUE = %{$self->{'FIELD_VALUE'}} ;
	my @FIELDS = @{$self->{'FIELDS'}} ; 
	# Makes the Where clause a WHERE clause.
	if ( $self->{'WHERE'} eq 'ALL' ) {  }
	elsif ( $self->{'WHERE'} ) { $whereclause = "WHERE $self->{'WHERE'}" } 
	my $fieldstring = '' ;
	 unless ( @FIELDS ) { 
		if ( $self->{'ACTION'} eq 'INSERT' or $self->{'ACTION'} eq 'UPDATE' ) { 
			$self->{'LASTERR'} =  "You must specify fields for INSERT or UPDATE! @FIELDS" 
			}
		$fieldstring = '*' ; } # select can use * if no fields are specified, delete and exec don't care.
	 elsif ( $self->{'ACTION'} eq 'SELECT' ) { }
	 else { 
	 	foreach my $F ( @FIELDS ) { $fieldstring = "$fieldstring\"$F\", " } ;
		$fieldstring =~ s/\,\s\z// ; #remove the trailing comma.
		} 
	my $valuestring = '' ;
	 unless ( @FIELDS ) { $valuestring = '(*)' }
	 else { 
		foreach my $F ( @FIELDS ) { $valuestring = qq /$valuestring'$FIELD_VALUE{$F}', / } ;
		$valuestring =~ s/\,\s\z// ; #remove the trailing comma		
		}  
	# This is to protect against accidental update without a where.
	my $query ;	
	# To support earlier versions I could not use given/when.
	if ( $self->{'ACTION'} eq 'COUNT' )  
		{ $query = qq / SELECT COUNT (*) FROM $self->{'TABLE'} $whereclause ;/ ; }		
	elsif ( $self->{'ACTION'} eq 'QUERY' ) { $query = $self->{'QUERY'} ; $self->{'QUERY'} = '' ; }
	elsif ( $self->{'ACTION'} eq 'SELECT' ) 
		{ $query = qq /$self->{'ACTION'} $self->{'FLAG'} * FROM $self->{'TABLE'} $whereclause ;/ ; }
#	elsif ( $self->{'ACTION'} eq 'EXEC' ) { return 'Exec is yet to be implemented.' }
	elsif ( $self->{'ACTION'} eq 'INSERT' ) 
		{ $query = qq /INSERT INTO $self->{'TABLE'}( $fieldstring ) VALUES ( $valuestring ) ; / ; }
	elsif ( $self->{'ACTION'} eq 'UPDATE' ) {
		unless ( values( %FIELD_VALUE ) )
			{ $self->{'LASTERR'} =  
				"You are attempting to update but have set no values" ; 
			return ; 
			} 
		unless ( $self->{'WHERE'} ) 
			{ $self->{'LASTERR'} =  
				"Error Not permitted to use Update without Where. To update ALL set where(ALL)." ;
			return ;
			} ;
		my $fieldset = '' ;
		foreach my $F ( @{$self->{'FIELDS'}} ) {
			if ( $FIELD_VALUE{$F} ) { 
				$fieldset = "$fieldset \"$F\"=\'$FIELD_VALUE{$F}\'," ; }
			}
		$fieldset =~ s/\,\z// ; #remove the trailing comma	
		$query = qq /UPDATE $self->{'TABLE'} SET $fieldset $whereclause ;/ ;
		} #$query = "$self->{'ACTION'} $fieldstring $self->{'TABLE'} $whereclause ;" ; 
			
	elsif ( $self->{'ACTION'} eq 'DELETE' ) 
		{ $query = "$self->{'ACTION'} FROM $self->{'TABLE'} $whereclause ;" ; } 
	else { 	$self->{'LASTERR'} = "Cannot process ACTION: $self->{'ACTION'} " ; 
		return $self->{'LASTERR'} ; 
		} ;
	$query =~ s/\s+/ /g ;
	return $query ;
} #write_query

sub where {
	my $self = shift ;
	$self->{'WHERE'} = shift ;
	}
	
sub setwhere {
	my ( $self, $field, $operator, $value ) = @_ ;
	$self->{'WHERE'} = qq / "$field" $operator '$value' / ;
	}

# fields executed without values will return the current list.
sub fields { 
	my $self = shift ;
	unless ( @_ ) { return @{$self->{'FIELDS'}} ;  }
	else { $self->{'FIELDS'} = [@_] ; }
	}

sub field_values { 
	my $self = shift ;
	my %FIELD_VALUE = (@_) ;	
	@{$self->{'FIELDS'}} = keys( %FIELD_VALUE ) ;
	$self->{'FIELD_VALUE'} = \%FIELD_VALUE ;
	}

sub preview {
	my $self = shift ; 
	my $switch = shift ;
	if ( $switch ) { $self->{'ACTION'} = $switch ; }
	return $self->__write_query__() ;
	}
	
sub __execute__ {
	my $self = shift ; 
	my $qs = $self->__write_query__() ;	
	$self->{'LASTERR'} = 0 ;
	$self->{'LASTROW'} = 0 ; # If the query is reused, this must be cleared.	
#say 144, $qs ;	
	unless( $qs ) { 
		$self->{'LASTERR'} = 'FAILED to generate valid query' ;
		return $self->{'LASTERR'} }
	$self->{'QH'} = $self->{'DBH'}->prepare( $qs ) ;
	unless ( $self->{'QH'} )  { 
		$self->{'LASTERR'} = $self->{'DBH'}->errstr  ; 
		return $self->{'LASTERR'} ; } 
	$self->{'QH'}->execute ;
	if ( $self->{'QH'}->err ) { 
		$self->{'LASTERR'} = $self->{'QH'}->errstr  ; 
		return $self->{'LASTERR'} ; }
	else { 
		if ( $self->{'ACTION'} eq 'SELECT' ) {
			my $key =  $self->{'QH'}->{NAME} ; 
			my @key = @$key ;
			$self->{'FIELDS'} = \@key  ; 
			} # Sets FIELDS to align with the return set!
		} 
	return $self->{'LASTERR'} ;	
	}

sub __domethod__ {
	my $self = shift ;
	my %HASH = @_ ;
	if ( defined $HASH{'CLEAR'} ) { $self->clear() } ;
	if ( defined $HASH{'WHERE'} )
		{ $self->where( $HASH{ 'WHERE' } ) ; } ;
	if ( defined $HASH{ 'SETWHERE' } ) { $self->setwhere( @{$HASH{ 'SETWHERE' }} ) ; } ;

# FLAG is probably eliminated, stored procs not yet implemented.
	# if ( defined $HASH{ 'FLAG' } )
		# { $self->{'FLAG'} = $HASH{ 'FLAG' } ;}
#	 if ( defined $HASH{ 'STORED_PROCEDURE' } )
#		{ $self->{'STORED_PROCEDURE'} = $HASH{ 'STORED_PROCEDURE' } ; } ;
		
	if ( defined $HASH{ 'FIELD_VALUE' } and defined $HASH{ 'FIELDS' } )
		{ $self->{'LASTERR'} =  "You should not specify both FIELDS and FIELD_VALUE" } ;
	if ( defined $HASH{ 'FIELD_VALUE' }) {
		$self->field_values( %{$HASH{ 'FIELD_VALUE' }} ) ; 
		$self->fields( keys %{$HASH{ 'FIELD_VALUE' }} ) ; } ;
	if ( defined $HASH{ 'FIELDS' }) 
		{ $self->fields( @{$HASH{ 'FIELDS' }} ) ;  } ;
#say , $self->preview() ;		
	return $self->__execute__() ;
#	return $self->{'LASTERR'} ;		
}

sub last_error { 
	my $self = shift ; 
	return $self->{'LASTERR'} ; }
sub last_row {	
	my $self = shift ; 
	return $self->{'LASTROW'} ; }

sub fetchrow {
	my $self = shift ;
	my @return = $self->{'QH'}->fetchrow_array ;
# This is never tested, maybe superfluous.	
#	if ( $self->{'QH'}->err ) { $self->{'LASTERR'} = $self->{'QH'}->errstr } 	
	unless( @return ) { $self->{'LASTROW'} = 1 ; $return[0] =  1 ; }
	return @return ;
	}

# DBI Documentation complains that the built in fetchrow_hasref isn't efficient.
# Since we already have the keys of a row set in @$self->{'FIELDS'}, we'll fetch a row
# and make our own hash.
sub fetchrow_hash {
	my $self = shift ;
	my @row = $self->{'QH'}->fetchrow_array ; 
# This is never tested, maybe superfluous.	
#	if ( $self->{'QH'}->err ) { $self->{'LASTERR'} = $self->{'QH'}->errstr } ;
	unless( @row ) { $self->{'LASTROW'} = 1 ; return () }	;
	my %RETURN =() ;	
	foreach my $F ( @{$self->{'FIELDS'}} ) {
		$RETURN{ $F } = shift @row ; }
#foreach my $K ( keys %RETURN  ) { say $RETURN{ $K } ; }
	return %RETURN ;
	}

sub count {
	my $self = shift ; 
	$self->{'ACTION'} = 'COUNT' ;
	$self->__domethod__( @_ ) ;	
	my @count = $self->fetchrow() ;
	return $count[0] ;
	}
	
sub count_all {
	my $self = shift ; 
	return $self->count( 'WHERE' => 'ALL' ) ;	
	}

sub query {
	my $self = shift ;
	$self->clear() ;
	$self->{'QUERY'}  = shift ;
	$self->{'ACTION'} = 'QUERY' ;
	return $self->__execute__() ;
}

sub select {
	my $self = shift ;
	$self->{'ACTION'} = 'SELECT' ;
	return $self->__domethod__( @_ ) ;
}
	
sub insert {
	my $self = shift ;
	$self->{'ACTION'} = 'INSERT' ;
	return $self->__domethod__( @_ ) ;
}

sub update {
	my $self = shift ;
	$self->{'ACTION'} = 'UPDATE' ;
	return $self->__domethod__( @_ ) ;
}

sub delete {
	my $self = shift ;
	$self->{'ACTION'} = 'DELETE' ;
	return $self->__domethod__( @_ ) ;
}
	

=head1 IhasQuery

=head2 Version 0.03

This Module aims to take the repetitiveness out of simple database activity. It delivers far less than an ORM like DBIC, but is also far simpler and easier to learn. At this time it only supports INSERT, UPDATE, DELETE, SELECT, and COUNT, and it supports a WHERE clause. It is also possible to execute a string as a SQL command. Future enhancements will support a Stored Procedure interface, GROUP BY and ORDER BY. It is not intended to add support for JOIN, if that support is ever added it would be implemented as mocking a View.

IhQ is a sensible choice if you are concerned with basic SQL operations, and can move any joins out to a View or Stored Procedure. It's advantage is that it is pretty simple and is intuitive if you already know SQL.

I presume that others have written similar wrappers in the past, and in fact IhasQuery is superficially similar to Fey:SQL, but differs significantly in that it requires no predefinition (it needs a DBI handle and the name of a table, which is close enough to no predefinition) and is dumber. 

=head2 Usage

	use IhasQuery ; 
 
	my $fieldname = <I>some field in sometable</I>  ;
	my $queryvalue = <I>some value I want to match</I> ;
	my $dbh = <I>... some code to create a DBI handle, see the DBI documentation...</I> ;
	my $table_stuff = IhasQuery->new( $dbh, 'stuff' ) ; 
	$table_stuff->setwhere( $fieldname, '=', $queryvalue ) ;
	say $table_stuff->preview( 'SELECT' ) ; # see the SQL for select
	$table_stuff->select() ; # do SQL
	my %HASH = $q->fetchrow_hash() ;
	# Execute the same query but in fewer lines
	$table_stuff->select( 'SETWHERE' => [ $fieldname, '=', $queryvalue ], ) ;

=head2 new

The new constructor requires a valid DBI Handle. It doesn't check anything, so you won't know anything is wrong until you try to execute something. By passing the DBI Handle rather than instiating it internally you can have any number of IhasQuery objects all sharing the same DBI Handle. The second argument binds the object to a specific table (required).

=head2 field_values, fields

This sets a Hash used when Fields/Values are required. fields is used to retrieve the list of fields in the current resultset, or in the hash that was passed into field_values. The list is internally updated when a select query is run or field_values are updated.

=head2 count, count_all

The count method immediately executes SELECT COUNT (*) with the current where clause, and returns the result as a simple scalar value. 
The count_all method does the same thing, but instead sets the current Where clause to ALL.

	my $count = $q->count() ;

=head2 where, setwhere

Provide the content of the where clause. The method where() requires providing the exact sql (don't include where as it is prepended when generating the query). The method setwhere() takes three arguments $fieldname, $operator, $value and creates the where clause. Normally if you want to return ALL rows pass the string 'ALL' to where. $q->where( 'ALL' ), if no where is specified, the default is ALL.

=head2 preview

preview() returns the query that would be executed. You should pass the operation as an upercase string, $q->preview('INSERT'), preview tries to generate a preview regardless. 

=head2 clear

Clears all current query settings. Whenever values are passed to an IhQ object they remain until overwritten or cleared. It is a good practice to use clear frequently. When 'CLEAR' is specified in the hash passed to a database method, a dummy value is required, the value passed is ignored and clear is processed first.

	$q->clear() ; # Clear all values held in $q.
	$q->select( 
	   'CLEAR' => 0 ,  # The value here does not matter, it is ignored.
	   'WHERE' => 'ALL' ) ;

=head2 fetchrow, fetchrow_hash

These two commands fetch the next row from the current resultset. fetchrow returns an array, fetchrow_hash returns a hash. When using fetchrow the fields method can be used to match fieldnames to the rows. 

=head2 last_row, last_error

After the last row is fetched with fetchrow or fetchrow_hash, the last_row method will return true, last_error returns the last DBI error recieved. Both of these values are cleared immediately before any query execution. 

=head2 Database Methods: delete, insert, select, update

These methods provide the sequel basics. Most of the other methods can be passed together in a hash, where the method name capitalized serves as the key. field_values and setwhere respectively require a hash reference and an array reference. The methods return 0 or the dbi error. Anything returned needs to be accessed with the fetchrow, fetchrow_hash and last_row methods.

=head2 query

query takes a string as an argument and passes it to dbi. As with the database methods it returns 0 on success or the error from dbi if there is one. As with the database methods, anything returned by the query needs to be accessed with the fetchrow, fetchrow_hash and last_row methods.

=head1 joins

IhasQuery does not currently support joins. Since joins should only be used on the server side in CREATE VIEW or STORED_PROCEDURE statements this is arguably a good thing. Since, in the real world programmers often do not have the proper access to the database, the eventual solution will be for IhasQuery to create its' own views and stored_update procedures. 

=head1 	Catalyst Models

If you want fast and simple access to your data, and don't need the intelligence and features that DBIx::Class offers, 
an IhasQuery Model may be just what the Doctor ordered. 

=head1 AUTHOR

John Karr, C<< <brainbuz at brainbuz.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-ihasquery at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=IhasQuery>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc IhasQuery


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=IhasQuery>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/IhasQuery>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/IhasQuery>

=item * Search CPAN

L<http://search.cpan.org/dist/IhasQuery/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2010 John Karr.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; version 3 or at your option
any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

A copy of the GNU General Public License is available in the source tree;
if not, write to the Free Software Foundation, Inc.,
59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.


=cut	
	
1; # End
