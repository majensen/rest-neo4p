# NAME

REST::Neo4p::Entity - Base class for Neo4j entities

# SYNOPSIS

Not intended to be used directly. Use subclasses
[REST::Neo4p::Node](/lib/REST/Neo4p/Node.md),
[REST::Neo4p::Relationship](/lib/REST/Neo4p/Relationship.md) and
[REST::Neo4p::Node](/lib/REST/Neo4p/Index.md) instead.

# DESCRIPTION

REST::Neo4p::Entity is the base class for the node, relationship and
index classes which should be used directly. The base class
encapsulates most of the [REST::Neo4p::Agent](/lib/REST/Neo4p/Agent.md) calls to the Neo4j
server, converts JSON responses to Perl references, acknowledges
errors, and maintains the main object table.

# SEE ALSO

[REST::Neo4p](/lib/REST/Neo4p.md), [REST::Neo4p::Node](/lib/REST/Neo4p/Node.md), [REST::Neo4p::Relationship](/lib/REST/Neo4p/Relationship.md),
[REST::Neo4p::Index](/lib/REST/Neo4p/Index.md).

# AUTHOR

    Mark A. Jensen
    CPAN ID: MAJENSEN
    majensen -at- cpan -dot- org

# LICENSE

Copyright (c) 2012-2020 Mark A. Jensen. This program is free software; you
can redistribute it and/or modify it under the same terms as Perl
itself.
