# NAME

REST::Neo4p::Constraint - Application-level Neo4j Constraints

# SYNOPSIS

See [REST::Neo4p::Constraint::Property](/lib/REST/Neo4p/Constraint/Property.md),
[REST::Neo4p::Constraint::Relationship](/lib/REST/Neo4p/Constraint/Relationship.md),
[REST::Neo4p::Constraint::RelationshipType](/lib/REST/Neo4p/Constraint/RelationshipType.md) for examples.

# DESCRIPTION

Objects of class REST::Neo4p::Constraint are used to capture and
organize [REST::Neo4p](/lib/REST/Neo4p.md) application level constraints on Neo4j Node
and Relationship content.

The [REST::Neo4p::Constrain](/lib/REST/Neo4p/Constrain.md) module provides a more convenient
factory for REST::Neo4p::Constraint subclasses that specify [node
property](/lib/REST/Neo4p/Constraint/Property.md), [relationship
property](/lib/REST/Neo4p/Property.md),
[relationship](/lib/REST/Neo4p/Constraint/Relationship.md), and
[relationship type](/lib/REST/Neo4p/Constraint/RelationshipType.md)
constraints.

# FLAGS

- `$REST::Neo4p::Constraint::STRICT_RELN_TYPES`

    When true, relationships are disallowed if the relationship type does
    not meet any current relationship type constraint. Default is true.

- `$REST::Neo4p::Constraint::STRICT_RELN_PROPS`

    When true, relationships are disallowed if their relationship
    properties do not meet any current relationship property constraint.

    Default is false. This is so relationships without properties can be
    made freely. When relationship property checking is strict, you can
    allow relationships without properties by setting the following
    constraint:

        create_constraint(
         tag => 'free_reln_prop',
         type => 'relationship_property',
         rtype => '*',
         condition => 'all',
         constraints => {}
        );

# METHODS

## Class Methods

- new()

        $reln_pc = REST::Neo4p::Constraint::RelationshipProperty->new($constraints);

    Constructor.  Construction also registers the constraint for
    validation. See subclass pod for details.

- get\_constraint()

        $c = REST::Neo4p::Constraint->get_constraint('spiffy_node');

    Get a registered constraint by constraint tag. Returns false if none found.

- get\_all\_constraints()

        %constraints = REST::Neo4p::Constraint->get_all_constraints();

    Get a hash of all registered constraint objects, keyed by constraint tag.

## Instance Methods

- tag()
- type()
- condition()
- set\_condition()

        $reln_c->set_condition('only');

    Set the group condition for the constraint. See subclass pod for details.

- priority()
- set\_priority()

        $node_pc->set_priority(10);

    Constraints with larger priority values are checked before those with
    smaller values by the [`validate_*()`](#functional-interface-for-validation) functions.

- constraints()

    Returns the hashref of constraints. Format depends on the subclass.

- add\_constraint()

        $node_pc->add_constraint( 'warning_level' => qr/^[0-9]$/ );
        $reln_c->add_constraint( { 'species' => 'genus' } );

    Add an individual constraint specification to an existing constraint
    object. See subclass pod for details.

- remove\_constraint()

        $node_pc->remove_constraint( 'warning_level' );
        $reln_c->remove_constraint( { 'genus' => 'species' } );

    Remove an individual constraint specification from an existing
    constraint object. See subclass pod for details.

## Functional interface for validation

- validate\_properties()

        validate_properties( $node_object )
        validate_properties( $relationship_object );
        validate_properties( { name => 'Steve', instrument => 'banjo' } );

- validate\_relationship()

        validate_relationship ( $relationship_object );
        validate_relationship ( $node_object1 => $node_object2, 
                                $reln_type );
        validate_relationship ( { name => 'Steve', instrument => 'banjo' } =>
                                { name => 'Marcia', instrument => 'blunt' },
                                'avoids' );

- validate\_relationship\_type()

        validate_relationship_type( 'avoids' )

Functional interface. Returns the registered constraint object with
the highest priority that the argument satisfies, or false if none is
satisfied.

These methods can be exported as follows:

    use REST::Neo4p::Constraint qw(:validate)

They can also be exported from [REST::Neo4p::Constrain](/lib/REST/Neo4p/Constrain.md):

    use REST::Neo4p::Constrain qw(:validate)

## Serializing and loading constraints

- serialize\_constraints()

        open $f, ">constraints.json";
        print $f serialize_constraints();

    Returns a JSON-formatted representation of all currently registered
    constraints.

- load\_constraints()

        open $f, "constraints.json";
        {
          local $/ = undef;
          load_constraints(<$f>);
        }

    Creates and registers a list of constraints specified by a JSON string
    as produced by ["serialize\_constraints()"](#serialize_constraints).

# SEE ALSO

[REST::Neo4p](/lib/REST/Neo4p.md),[REST::Neo4p::Constrain](/lib/REST/Neo4p/Constrain.md),
[REST::Neo4p::Constraint::Property](/lib/REST/Neo4p/Constraint/Property.md), [REST::Neo4p::Constraint::Relationship](/lib/REST/Neo4p/Constraint/Relationship.md),
[REST::Neo4p::Constraint::RelationshipType](/lib/REST/Neo4p/Constraint/RelationshipType.md). [REST::Neo4p::Node](/lib/REST/Neo4p/Node.md), [REST::Neo4p::Relationship](/lib/REST/Neo4p/Relationship.md),

# AUTHOR

    Mark A. Jensen
    CPAN ID: MAJENSEN
    majensen -at- cpan -dot- org

# LICENSE

Copyright (c) 2012-2022 Mark A. Jensen. This program is free software; you
can redistribute it and/or modify it under the same terms as Perl
itself.
