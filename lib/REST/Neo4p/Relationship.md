# NAME

REST::Neo4p::Relationship - Neo4j relationship object

# SYNOPSIS

    $n1 = REST::Neo4p::Node->new( {name => 'Harry'} );
    $n2 = REST::Neo4p::Node->new( {name => 'Sally'} );
    $r1 = $n1->relate_to($n2, 'met');
    $r1->set_property({ when => 'July' });

    $r2 = REST::Neo4p::Relationship->new( $n2 => $n1, 'dropped' );

# DESCRIPTION

REST::Neo4p::Relationship objects represent Neo4j relationships.

# METHODS

- new()

        $r1 = REST::Neo4p::Relationship->new($node1, $node2, 'ingratiates');

    Creates the relationship given by the scalar third argument between
    the first argument and second argument, both `REST::Neo4p::Node`
    objects. An optional fourth argument is a hashref of _relationship_ 
    properties.

- remove()

        $reln->remove()

    Removes the relationship from the database.

- get\_property()

        $status = $reln->get_property('status');

    Get the values of properties on nodes and relationships.

- set\_property()

        $node1->relate_to($node2,"is_pal_of")->set_property( {duration => 'old pal'} );

    Sets values of properties on nodes and relationships.

- get\_properties()

        $props = $relationship->get_properties;
        print "Come here often?" if ($props->{status} eq 'not_currently_seeing');

    Get all the properties of relationship as a hashref.

- remove\_property()

        $relationship->remove_property('name');
        $relationship->remove_property(@property_names);

    Remove properties from relationship.

- start\_node(), end\_node()

        $fred_node = $married_to->start_node;
        $wilma_node = $married_to->end_node;

    Get the start and end nodes of the relationship.

- type()

        $rel = $node->relate_to($node2, 'my_type');
        print "This is my_type of relationship" if $rel->type eq 'my_type';

    Gets a relationship's type.

- Property auto-accessors

    See ["Property Auto-accessors" in REST::Neo4p](/lib/REST/Neo4p#Property-Auto-accessors.md).

- as\_simple()

        $simple_reln = $reln1->as_simple
        $rel_id = $simple_reln->{_relationship};
        $value = $simple_reln->{$property_name};
        $type = $simple_reln->{_type};
        $start_node_id = $simple_reln->{_start};
        $end_node_id = $simple_reln->{_end};

    Get relationship as a simple hashref.

# SEE ALSO

[REST::Neo4p](/lib/REST/Neo4p.md), [REST::Neo4p::Node](/lib/REST/Neo4p/Node.md), [REST::Neo4p::Index](/lib/REST/Neo4p/Index.md).

# AUTHOR

    Mark A. Jensen
    CPAN ID: MAJENSEN
    majensen -at- cpan -dot- org

# LICENSE

Copyright (c) 2012-2020 Mark A. Jensen. This program is free software; you
can redistribute it and/or modify it under the same terms as Perl
itself.
