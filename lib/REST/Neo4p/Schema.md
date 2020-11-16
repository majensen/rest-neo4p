# NAME

REST::Neo4p::Schema - Label-based indexes and constraints

# SYNOPSIS

    REST::Neo4p->connect($server);
    $schema = REST::Neo4p::Schema->new;
    $schema->create_index('Person','name');
    

# DESCRIPTION

[Neo4j](http://neo4j.org) v2.0+ provides a way to schematize the graph
on the basis of node labels, associated indexes, and property
uniqueness constraints. `REST::Neo4p::Schema` allows access to this
system via the Neo4j REST API. Use a `Schema` object to create, list,
and drop indexes and constraints.

# METHODS

- create\_index()

        $schema->create_index('Label', 'property');
        $schema->create_index('Label', @properties);

    The second example is convenience for creating multiple single indexes
    on each of a list of properties. It does not create a compound index
    on the set of properties. Returns TRUE.

- get\_indexes()

        @properties = $schema->get_indexes('Label');

    Get a list properties on which an index exists for a given label.

- drop\_index()

        $schema->drop_index('Label','property');
        $schema->drop_index('Label', @properties);

    Remove indexes on given property or properties for a given label.

- create\_unique\_constraint()

        $schema->create_unique_constraint('Label', 'property');
        $schema->create_unique_constraint('Label', @properties);

    Create uniqueness constraints on a given property or properties for a
    given label.

    _Note_: For some inexplicable reason, this one schema feature went behind
    the paywall in Neo4j version 4.0. Unless you are using the Enterprise
    Edition, this method will throw the dreaded
    [REST::Neo4p::Neo4jTightwadException](/lib/REST/Neo4p/Neo4jTightwadException.md).

- get\_constraints()

        @properties = $schema->get_constraints('Label');

    Get a list of properties for which (uniqueness) constraints exist for
    a given label.

- drop\_unique\_constraint()

        $schema->drop_unique_constraint('Label', 'property');
        $schema->drop_unique_constraint('Label', @properties);

    Remove uniqueness constraints on given property or properties for a
    given label.

# SEE ALSO

[REST::Neo4p](/lib/REST/Neo4p.md), [REST::Neo4p::Index](/lib/REST/Neo4p/Index.md), [REST::Neo4p::Query](/lib/REST/Neo4p/Query.md)

# AUTHOR

    Mark A. Jensen
    CPAN ID: MAJENSEN
    majensen -at- cpan -dot- org

# LICENSE

Copyright (c) 2012-2020 Mark A. Jensen. This program is free software; you
can redistribute it and/or modify it under the same terms as Perl
itself.
