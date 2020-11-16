# NAME

REST::Neo4p::Constrain - Create and apply Neo4j app-level constraints

# SYNOPSIS

    use REST::Neo4p;
    use REST::Neo4p::Constrain qw(:all); # not included by REST::Neo4p
    
    # create some constraints
    
     create_constraint (
     tag => 'owner',
     type => 'node_property',
     condition => 'only',
     constraints => {
       name => qr/[a-z]+/i,
       species => 'human'
     }
    );
    
    create_constraint(
     tag => 'pet',
     type => 'node_property',
     condition => 'all',
     constraints => {
       name => qr/[a-z]+/i,
       species => qr/^dog|cat|ferret|mole rat|platypus$/
     }
    );
    
    create_constraint(
     tag => 'OWNS_props',
     type => 'relationship_property',
     rtype => 'OWNS',
     condition => 'all',
     constraints => {
       year_purchased => qr/^20[0-9]{2}$/
     }
    );

    create_constraint(
     tag => 'owners_own_pets',
     type => 'relationship',
     rtype => 'OWNS',
     constraints =>  [{ owner => 'pet' }] # note arrayref
    );

    create_constraint(
     tag => 'loves',
     type => 'relationship',
     rtype => 'LOVES',
     constraints =>  [{ pet => 'owner' },
                      { owner => 'pet' }] # both directions ok
    );

    create_constraint(
     tag => 'ignore'
     type => 'relationship',
     rtype => 'IGNORES',
     constraints =>  [{ pet => 'owner' },
                      { owner => 'pet' }] # both directions ok
    );

    create_constraint(
     tag => 'allowed_rtypes',
     type => 'relationship_type',
     constraints => [qw( OWNS FEEDS LOVES )] 
     # IGNORES is missing, see below
    );

    # constrain by automatic exception-throwing

    constrain();

    $fred = REST::Neo4p::Node->new( 
     { name => 'fred', species => 'human' }
    );
    $fluffy = REST::Neo4p::Node->new( 
     { name => 'fluffy', species => 'mole rat' }
    );

    $r1 = $fred->relate_to(
     $fluffy, 'OWNS', {year_purchased => 2010}
    ); # valid
    eval {
      $r2 = $fluffy->relate_to($fred, 'OWNS', {year_purchased => 2010});
    };
    if (my $e = REST::Neo4p::ConstraintException->caught()) {
      print STDERR "Pet can't own an owner, ignored\n";
    }

    eval {
      $r3 = $fluffy->relate_to($fred, 'IGNORES');
    };
    if (my $e = REST::Neo4p::ConstraintException->caught()) {
      print STDERR "Pet can't ignore an owner, ignored\n";
    }

    # allow relationship types that are not explictly
    # allowed -- a relationship constraint is still required

    $REST::Neo4p::Constraint::STRICT_RELN_TYPES = 0;

    $r3 = $fluffy->relate_to($fred, 'IGNORES'); # no throw now

    relax(); # stop automatic constraints

    # use validation

    $r2 = $fluffy->relate_to(
     $fred, 'OWNS',
     {year_purchased => 2010}
    ); # not valid, but auto-constraint not in force

    if ( validate_properties($r2) ) {
      print STDERR "Relationship properties are valid\n";
    }
    if ( !validate_relationship($r2) ) {
      print STDERR 
       "Relationship does not meet constraints, ignoring...\n";
    }

    # try a relationship

    if ( validate_relationship( $fred => $fluffy, 'LOVES' ) {
      $fred->relate_to($fluffy, 'LOVES');
    }
    else {
      print STDERR 
       "Prospective relationship fails constraints, ignoring...\n";
    }

    # try a relationship type

    if ( validate_relationship( $fred => $fluffy, 'EATS' ) {
      $fred->relate_to($fluffy, 'EATS');
    }
    else {
      print STDERR 
       "Relationship type disallowed, ignoring...\n";
    }

    # serialize all constraints

    open $f, ">my_constraints.json";
    print $f serialize_constraints();
    close $f;

    # remove current constraints

    while ( my ($tag, $constraint) = 
              each REST::Neo4p::Constraint->get_all_constraints ) {
      $constraint->drop;
    }

    # restore constraints

    open $f, "my_constraints.json";
    local $/ = undef;
    $json = <$f>;
    load_constraints($json);

# DESCRIPTION

[Neo4j](http://neo4j.org), as a NoSQL database, is intentionally
lenient. One of its only hardwired constraints is its refusal to
remove a Node that is involved in a Relationship. Other constraints to
database content (properties and their values, "kinds" of
relationships, and relationship types) must be applied at the
application level.

[REST::Neo4p::Constrain](/lib/REST/Neo4p/Constrain.md) and [REST::Neo4p::Constraint](/lib/REST/Neo4p/Constraint.md) attempt to
provide a flexible framework for creating and enforcing Neo4j content
constraints for applications using [REST::Neo4p](/lib/REST/Neo4p.md).

The use case that inspired these modules is the following: You start
out with a set of well categorized things, that have some well defined
relationships. Each thing will be represented as a node, that's
fine. But you want to guarantee (to your client, for example) that

- 1. You can classify every node you add or read unambiguously into
a well-defined group;
- 2. You never relate two nodes belonging to particular groups in a
way that doesn't make sense according to your well-defined
relationships.

These modules allow you to create a set of constraints on node
and relationship properties, relationships themselves, and
relationship types to meet this use case and others. It is flexible,
in that you can choose the level at which the validation is applied:

- You can make [REST::Neo4p](/lib/REST/Neo4p.md) throw exceptions when registered
constraints are violated before object creation/database insertion or
updating;
- You can validate properties and relationships using methods in
the code;
- You can check the validity of [Node](/lib/REST/Neo4p/Node.md) or
[Relationship](/lib/REST/Neo4p/Relationship.md) objects as retrieved from
the database

The ["SYNOPSIS"](#synopsis) is a full example.

## Types of Constraints

[REST::Neo4p::Constrain](/lib/REST/Neo4p/Constrain.md) handles four types of constraints.

- Node property constraints

    A node property constraint specifies the presence/absence of
    properties, and can specify the allowable values a property must (or
    must not) take.

- Relationship property constraints

    A relationship property constraint specifies the presence/absence of
    properties, and can specify the allowable values a property must (or
    must not) take. In addition, a relationship property constraint can be
    linked to a given relationship type, so that, e.g., the creation of a
    relationship of a given type can be forced to have specified
    relationship properties.

- Relationship constraints

    A relationship constraint specifies which "kinds" of nodes can
    participate in a relationship of a given type. A node's "kind" is
    determined by what node property constraint its properties satisfy.

- Relationship type constraints

    A relationship type constraint simply enumerates the allowable (or
    disallowed) relationship types.

## Specifying Constraints

[REST::Neo4p::Constrain](/lib/REST/Neo4p/Constrain.md) exports `create_constraint()`, which
creates and registers the different constraint types. (It also returns
the [REST::Neo4p::Constraint](/lib/REST/Neo4p/Constraint.md) object so created, which can be
useful.)

`create_constraint` accepts a hash of parameters. The following are required:

    create_constraint(
     tag => $tag, # a (preferably) simple and meaningful alias for this
                  # constraint
     type => $type, # node_property|relationship_property|
                    # relationship|relationship_type
     priority => $integer_priority, # to determine which constraints
                                    # are evaluated first during validation
     constraints => $constraints, # a reference that depends on the
                                # constraint type, see below
    );

Other parameters and the form of the constraint values depend on the
constraint type:

- Node property

    The constraints are specified as a hashref whose keys are the property
    names and values are the constraints on the property values.

        constraints => {
           # property must be present, may have any value
           prop_1 => '',
           # property must be present, and value must eq 'value'
           prop_2 => 'value', 
           # property must be present, and value must match qr/.alue/
           prop_3 => qr/.alue/, 
           # property may be present, and may have any value
           prop_4 => [],
           # property may be present, if present
           # value must match the given condition
           prop_5 => [<string|regexp>],
           # (use regexps for enumerations)
           prop_6 => qr/^value1|value2|value3$/ 
        }

    A `condition` parameter can be specified:

        condition => 'all'  # all the specified constraints must be met, and
                            # other properties not in the constraint list may
                            # be added freely

        condition => 'only' # all the specified constraint must be met, and
                            # no other properties may be added

        condition => 'none' # reject if any of the specified constraints is
                            # satisfied ('blacklist')

    `condition` defaults to 'all'.

- Relationship property

    Constraints on properties are specified as for node properties above.

    A relationship type can be associated with the relationship property
    constraint with the parameter `rtype`:

        rtype => $relationship_type # any relationship type name, or '*' for all types

    The `condition` parameter works as for node properties above.

- Relationship

    The basic constraint on a relationship is specified as a hashref that
    maps a "kind" of from-node to a "kind" of to-node. The "kind" of node
    is indicated by the tag of the node property constraint it satisfies.

    The `constraints` parameter takes an arrayref of these one-row hashrefs.

    The `rtype` parameter specifies the relationship type to which the
    constraint applies.

    Here's an example. Create the following node property constraints:

        create_constraint(
         tag => 'owner',
         type => 'node_property',
         constraints => {
           name => qr/a-z/i,
           species => 'human'
         }
        );

        create_constraint(
         tag => 'pet',
         type => 'node_property',
         constraints => {
           name => qr/a-z/i,
           species => qr/^dog|cat|ferret|mole rat|platypus$/
         }
        );

    Then a relationship constraint that specifies owners can own pets is

        create_constraint(
         tag => 'owners2pets',
         type => 'relationship',
         rtype => 'OWNS',
         constraints =>  [{ owner => 'pet' }] # note arrayref
        );
        

    In [REST::Neo4p](/lib/REST/Neo4p.md) terms, if this constraint (and only this one) is registered,

        $fred = REST::Neo4p::Node->new( { name => 'fred', species => 'human' } );
        $fluffy = REST::Neo4p::Node->new( { name => 'fluffy', species => 'mole rat' } );

        $r1 = $fred->relate_to($fluffy, 'OWNS'); # valid
        $r2 = $fluffy->relate_to($fred, 'OWNS'); # NOT VALID, throws when
                                                 # constrain() is in force

- Relationship type

    The relationship type constraint is just an arrayref of relationship types.

        constraints => [@rel_types]

    The `condition` parameter can take the following values:

        condition => 'only' # new relationships must have one of the listed
                            # types (whitelist)

        condition => 'none' # no new relationship may have any of the listed
                            # types (blacklist)

## Using Constraints

[`create_constraint()`](#create_constraint) registers the created
constraint so that it is included in all relevant validations.

[`drop_constraint()`](#drop_constraint) deregisters and removes the
constraint specified by its tag:

    drop_constraint('owner');
    drop_constraint('pet');

### Automatic validation

Execute [`constrain()`](#constrain) to force [REST::Neo4p](/lib/REST/Neo4p.md) to raise a
[REST::Neo4p::ConstraintException](/lib/REST/Neo4p/Exceptions.md) whenever
the construction or modification of a Node or Relationship would
violate the registered constraints.

Executing [`relax()`](#relax) causes [REST::Neo4p](/lib/REST/Neo4p.md) to ignore all
constraint and create and modify entities as usual.

`constrain()` and `relax()` can be used anywhere at any time. The
effects are global.

When `constrain()` is in force, any new constraints created are
immediately available to the validation.

### "Manual" validation

To control validation directly, use the `:validate` export tag:

    use REST::Neo4p::Constrain qw(:validate);

This provides three functions for checking properties, relationships,
and relationship types against registered constraints. They return
true if the object or spec satisfies the current constraints and false
if it violates the current constraints. No constraint exceptions are
raised.

### Controlling relationship validation strictness

You can set whether relationship types or relationship properties are
strictly validated or not, even when constraints are in
force. Relaxing one or both of these can allow you to follow
constraints you have defined strictly, while enabling other kinds of
relationships to be created ad hoc outside of validation.

See [REST::Neo4p::Constraint](#flags) for details.

# FUNCTIONS

## Exported by default

- create\_constraint()

        create_constraint( 
         tag => $meaningful_tag,
         type => $constraint_type,   # [node_property|relationship_property|
                                     #  relationship|relationship_type]
         condition => $condition     # all|only|none, depends on type
         rtype => $relationship_type # relationship type tag
         constraints => $spec_ref    # hashref or arrayref, depends on type
        );

    Creates and registers a constraint. Returns the created [REST::Neo4p::Constraint](/lib/REST/Neo4p/Constraint.md) object.

    See ["Specifying Constraints"](#specifying-constraints) for details.

- drop\_constraint()

        drop_constraint($constraint_tag);

    Deregisters a constraint identified by its tag. Returns the constraint object.

- constrain()
- relax()

        constrain();
        eval {
          $node = REST::Neo4p::Node->create({foo => bar, baz => 1});
        };
        if ($e = REST::Neo4p::ConstraintException->caught()) {
          relax();
          print "Got ".$e->msg.", but creating anyway\n";
          $node = REST::Neo4p::Node->create({foo => bar, baz => 1});
        }

    constrain() forces [REST::Neo4p](/lib/REST/Neo4p.md) constructors and property setters to
    comply with the currently registered
    constraints. [REST::Neo4p::Exceptions](/lib/REST/Neo4p/ConstraintException.md)s
    are thrown if constraints are not met.

    relax() turns off the automatic validation of constrain().

    Effects are global.

## Serialization functions

Use these functions to freeze and thaw the currently registered
constraints to and from a JSON representation.

Import with

    use REST::Neo4p::Constrain qw(:serialize);

- serialize\_constraints()

        open $f, ">constraints.json";
        print $f serialize_constraints();

    Returns a JSON-formatted representation of all currently registered constraints.

- load\_constraints()

        open $f, "constraints.json";
        {
          local $/ = undef;
          load_constraints(<$f>);
        }

    Creates and registers a list of constraints specified by a JSON string
    as produced by ["serialize\_constraints()"](#serialize_constraints).

## Validation functions

Functional interface. Returns the registered constraint object with
the highest priority that the argument satisfies, or false if no
constraint is satisfied.

Import with

    use REST::Neo4p::Constrain qw(:validate);

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

    These methods can also be exported from [REST::Neo4p::Constraint](/lib/REST/Neo4p/Constraint.md).

# SEE ALSO

[REST::Neo4p](/lib/REST/Neo4p.md), [REST::Neo4p::Constraint](/lib/REST/Neo4p/Constraint.md)

# AUTHOR

    Mark A. Jensen
    CPAN ID: MAJENSEN
    majensen -at- cpan -dot- org

# LICENSE

Copyright (c) 2012-2020 Mark A. Jensen. This program is free software; you
can redistribute it and/or modify it under the same terms as Perl
itself.
