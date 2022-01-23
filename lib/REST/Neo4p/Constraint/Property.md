# NAME

REST::Neo4p::Constraint::Property - Neo4j Property Constraints

# SYNOPSIS

    # use REST::Neo4p::Constrain, it's nicer

    $npc = REST::Neo4p::Constraint::NodeProperty->new(
      'soldier' => { _condition => 'all',
                     _priority => 1,
                     name => '',
                     rank => [],
                     serial_number => qr/^[0-9]+$/,
                     army_of => 'one' }
     );

    $rpc = REST::Neo4p::Constraint::RelationshipProperty->new(
     'position' => { _condition => 'only',
                     position => qr/[0-9]+/ }
     );

# DESCRIPTION

`REST::Neo4p::Constraint::NodeProperty` and
`REST::Neo4p::Constraint::RelationshipProperty` are classes that
represent constraints on the presence and values of Node and
Relationship entities.

Constraint hash specification:

     { 
       _condition => constraint_conditions, # ('all'|'only'|'none')
       _relationship_type => <relationship type>,
       _priority => <integer priority>,
       prop_0 => [], # may have, no constraint
       prop_1 => [<string|regexp>], # may have, if present must meet 
       prop_2 => '', # must have, no constraint
       prop_3 => 'value', # must have, value must eq 'value'
       prop_4 => qr/.alue/, # must have, value must match qr/.alue/,
       prop_5 => qr/^value1|value2|value3$/ # regexp for enumerations
    }

# METHODS

- new()

        $np = REST::Neo4p::Constraint::NodeProperty->new(
                $tag => $constraint_hash
              );

        $rp = REST::Neo4p::Constraint::RelationshipProperty->new(
                $tag => $constraint_hash
              );

- add\_constraint()

        $np->add_constraint( optional_accessory => [qw(tie ascot boutonniere)] );

- remove\_constraint()

        $np->remove_constraint( 'unneeded_property' );

- tag()

    Returns the constraint tag.

- type()

    Returns the constraint type ('node\_property' or 'relationship\_property').

- condition()
- set\_condition()

    Set/get 'all', 'only', 'none' for a given property constraint. See
    [REST::Neo4p::Constrain](/lib/REST/Neo4p/Constrain.md).

- priority()
- set\_priority()

    Constraints with higher priority will be checked before constraints
    with lower priority by
    [`validate_properties()`](/lib/REST/Neo4p/Constraint#Functional-interface-for-validation.md).

- constraints()

    Returns the internal constraint spec hashref.

- validate()

        $c->validate( $node_object )
        $c->validate( $relationship_object )
        $c->validate( { name => 'Steve', instrument => 'banjo } );

    Returns true if the item meets the constraint, false if not.

# SEE ALSO

[REST::Neo4p](/lib/REST/Neo4p.md), [REST::Neo4p::Node](/lib/REST/Neo4p/Node.md), [REST::Neo4p::Relationship](/lib/REST/Neo4p/Relationship.md),
[REST::Neo4p::Constraint](/lib/REST/Neo4p/Constraint.md), [REST::Neo4p::Constraint::Relationship](/lib/REST/Neo4p/Constraint/Relationship.md),
[REST::Neo4p::Constraint::RelationshipType](/lib/REST/Neo4p/Constraint/RelationshipType.md).

# AUTHOR

    Mark A. Jensen
    CPAN ID: MAJENSEN
    majensen -at- cpan -dot- org

# LICENSE

Copyright (c) 2012-2022 Mark A. Jensen. This program is free software; you
can redistribute it and/or modify it under the same terms as Perl
itself.
