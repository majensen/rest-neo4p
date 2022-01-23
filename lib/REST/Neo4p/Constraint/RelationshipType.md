# NAME

REST::Neo4p::Constraint::RelationshipType - Neo4j Relationship Type Constraints

# SYNOPSIS

    # use REST::Neo4p::Constrain, it's nicer

    $rtc = REST::Neo4p::Constraint::RelationshipType->new(
     'allowed_reln_types' =>
       { _condition => 'only', 
         _type_list => [qw(contains has)] }
     );

# DESCRIPTION

`REST::Neo4p::Constraint::RelationshipType` is a class that represent
the set of relationship types that Relationships must (or must not)
use.

Constraint hash specification:

    { 
      _condition => <'only'|'none'>,
      _priority => <integer priority>,
      _type_list => [ 'type_name_1', 'type_name_2', ...]  }
    }

# METHODS

- new()

        $rt = REST::Neo4p::Constraint::RelationshipType->new(
                $tag => $constraint_hash
              );

- add\_constraint()
- add\_types()

        $rc->add_constraint('new_type');
        $rc->add_type('new_type');

- remove\_constraint()
- remove\_type()

        $rc->remove_constraint('old_type');
        $rc->remove_type('old_type');

- tag()

    Returns the constraint tag.

- type()

    Returns the constraint type ('relationship\_type').

- condition()
- set\_condition()

    Get/set 'only' or 'none' for a given relationship constraint. See
    [REST::Neo4p::Constrain](/lib/REST/Neo4p/Constrain.md).

- priority()
- set\_priority()

    Constraints with higher priority will be checked before constraints
    with lower priority by
    [`validate_relationship_type()`](/lib/REST/Neo4p/Constraint#Functional-interface-for-validation.md).

- constraints()

    Returns the internal constraint spec hashref.

- validate()

        $c->validate( 'avoids' );

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
