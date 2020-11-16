# NAME

REST::Neo4p::Node - Neo4j node object

# SYNOPSIS

    $n1 = REST::Neo4p::Node->new( {name => 'Ferb'} )
    $n2 = REST::Neo4p::Node->new( {name => 'Phineas'} );
    $n3 = REST::Neo4p::Node->new( {name => 'Perry'} );
    $n1->relate_to($n2, 'brother');
    $n3->relate_to($n1, 'pet');
    $n3->set_property({ species => 'Ornithorhynchus anatinus' });

# DESCRIPTION

REST::Neo4p::Node objects represent Neo4j nodes.

# METHODS

- new()

        $node = REST::Neo4p::Node->new();
        $node_with_properties = REST::Neo4p::Node->new( \%props );

    Instantiates a new Node object and creates corresponding node in the database.

- remove()

        $node->remove()

    **CAUTION**: Removes a node from the database and destroys the object.

- get\_property()

        $name = $node->get_property('name');
        @vitals = $node->get_property( qw( height weight bp temp ) );

    Get the values of properties on nodes and relationships.

- set\_property()

        $name = $node->set_property( {name => "Sun Tzu", occupation => "General"} );
        $node1->relate_to($node2,"is_pal_of")->set_property( {duration => 'old pal'} );

    Sets values of properties on nodes and relationships.

- get\_properties()

        $props = $node->get_properties;
        print "'Sup, Al." if ($props->{name} eq 'Al');

    Get all the properties of a node or relationship as a hashref.

- remove\_property()

        $node->remove_property('name');
        $node->remove_property(@property_names);

    Remove properties from node.

- relate\_to()

        $relationship = $node1->relate_to($node2, 'manager', { matrixed => 'yes' });

    Create a relationship between two nodes in the database and return the
    [REST::Neo4p::Relationship](/lib/REST/Neo4p/Relationship.md) object. Call on the "from" node, first
    argument is the "to" node, second argument is the relationship type,
    third optional argument is a hashref of _relationship_ properties.

- get\_relationships()

        @all_relationships = $node1->get_relationships()

    Get all incoming and outgoing relationships of a node. Returns array
    of [REST::Neo4p::Relationship](/lib/REST/Neo4p/Relationship.md) objects;

- get\_incoming\_relationships()

        @incoming_relationships = $node1->get_incoming_relationships();

- get\_outgoing\_relationships()

        @outgoing_relationships = $node1->get_outgoing_relationships();

- property auto-accessors

    See ["Property Auto-accessors" in REST::Neo4p](/lib/REST/Neo4p#Property-Auto-accessors.md).

- as\_simple()

        $simple_node = $node1->as_simple
        $node_id = $simple_node->{_node};
        $value = $simple_node->{$property_name};

    Get node as a simple hashref.

## METHODS - Neo4j Version 2.0+

These methods are supported by v2.0+ of the Neo4j server.

- set\_labels()

        my $node = $node->set_labels($label1, $label2);

    Sets the node's labels. This replaces any existing node labels.

- add\_labels()

        my $node = $node->add_labels($label3, $label4);

    Add labels to the nodes existing labels.

- get\_labels()

        my @labels = $node->get_labels;

    Retrieve the node's list of labels, if any.

- drop\_labels()

        my $node = $node->drop_labels($label1, $label4);

    Remove one or more labels from a node.

# SEE ALSO

[REST::Neo4p](/lib/REST/Neo4p.md), [REST::Neo4p::Relationship](/lib/REST/Neo4p/Relationship.md), [REST::Neo4p::Index](/lib/REST/Neo4p/Index.md).

# AUTHOR

    Mark A. Jensen
    CPAN ID: MAJENSEN
    majensen -at- cpan -dot- org

# LICENSE

Copyright (c) 2012-2020 Mark A. Jensen. This program is free software; you
can redistribute it and/or modify it under the same terms as Perl
itself.
