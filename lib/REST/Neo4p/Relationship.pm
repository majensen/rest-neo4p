#$Id: Relationship.pm 17677 2012-09-19 23:32:48Z jensenma $
package REST::Neo4p::Relationship;
use base 'REST::Neo4p::Entity';
use REST::Neo4p;
use Carp qw(croak carp);
use strict;
use warnings;
BEGIN {
  $REST::Neo4p::Relationship::VERSION = '0.1282';
}

sub new {
  my $self = shift;
  my ($from_node, $to_node, $type) = @_;
  unless (ref $from_node && $from_node->is_a('REST::Neo4p::Node') &&
	  ref $to_node && $to_node->is_a('REST::Neo4p::Node') &&
	  defined $type) {
    REST::Neo4p::LocalException->throw("Requires 2 REST::Neo4p::Node objects and a relationship type\n");
  }
  return $from_node->relate_to($to_node, $type);
}

sub type {
  my $self = shift;
  return $self->_entry->{type};
}

sub start_node {
  return REST::Neo4p->get_node_by_id(shift->_entry->{start_id});
}

sub end_node {
  return REST::Neo4p->get_node_by_id(shift->_entry->{end_id});
}

=head1 NAME

REST::Neo4p::Relationship - Neo4j relationship object

=head1 SYNOPSIS

 $n1 = REST::Neo4p::Node->new( {name => 'Harry'} )
 $n2 = REST::Neo4p::Node->new( {name => 'Sally'} );
 $r1 = $n1->relate_to($n2, 'met');
 $r1->set_property({ when => 'July' });

=head1 DESCRIPTION

C<REST::Neo4p::Relationship> objects represent Neo4j relationships.

=head1 METHODS

=over

=item new()

 $r1 = REST::Neo4p::Relationship->new($node1, $node2, 'ingratiates');

Creates the relationship given by the scalar third argument between
the first argument and second argument, both C<REST::Neo4p::Node>
objects.

=item get_property()

 $name = $node->get_property('name');
 @vitals = $node->get_property( qw( height weight bp temp ) );

Get the values of properties on nodes and relationships.

=item set_property()

 $name = $node->set_property( {name => "Sun Tzu", occupation => "General"} );
 $node1->relate_to($node2,"is_pal_of")->set_property( {duration => 'old pal'} );

Sets values of properties on nodes and relationships.

=item get_properties()

 $props = $relationship->get_properties;
 print "'Sup, Al." if ($props->{name} eq 'Al');

Get all the properties of a node or relationship as a hashref.

=item start_node(), end_node()

 $fred_node = $married_to->start_node;
 $wilma_node = $married_to->end_node;

Get the start and end nodes of the relationship.

=item type()

 $rel = $node->relate_to($node2, 'my_type');
 print "This is my_type of relationship" if $rel->type eq 'my_type';

Gets a relationship's type.

=item property auto-accessors

See L<REST::Neo4p/Property Auto-accessors>.

=back

=head1 SEE ALSO

L<REST::Neo4p>, L<REST::Neo4p::Node>, L<REST::Neo4p::Index>.

=head1 AUTHOR

    Mark A. Jensen
    CPAN ID: MAJENSEN
    majensen -at- cpan -dot- org

=head1 LICENSE

Copyright (c) 2012 Mark A. Jensen. This program is free software; you
can redistribute it and/or modify it under the same terms as Perl
itself.

=cut

1;
