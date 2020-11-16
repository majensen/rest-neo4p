# NAME

REST::Neo4p::Path - Container for Neo4j path elements

# SYNOPSIS

    use REST::Neo4p::Query;
    $query = REST::Neo4p::Query->new(
      'START n=node(0), m=node(1) MATCH p=(n)-[*..3]->(m) RETURN p'
    );
    $query->execute;
    $path = $query->fetch->[0];
    @nodes = $path->nodes;
    @relns = $path->relationships;
    while ($n = shift @nodes) {
      my $r = shift @relns;
      print $r ? $n->id."-".$r->id."->" : $n->id."\n";
    }

# DESCRIPTION

REST::Neo4p::Path provides a simple container for Neo4j paths as returned
by Cypher queries. Nodes and relationships are stored in path order.

Creating de novo instances of this class is really the job of [REST::Neo4p::Query](/lib/REST/Neo4p/Query.md).

# METHODS

- nodes()

        @nodes = $path->nodes;

    Get the nodes in path order.

- relationships()

        @relationships = $path->relationships;

    Get the relationships in path order.

- as\_simple()

        $a = $path->as_simple;
        @simple_nodes = grep { $_->{_node} } @$a;
        @simple_relns = grep { $_->{_relationship} } @$a;

    Get the path as an array of simple node and relationship hashes (see
    ["as\_simple()" in REST::Neo4p::Node](/lib/REST/Neo4p/Node#as_simple.md),
    ["as\_simple()" in REST::Neo4p::Relationship](/lib/REST/Neo4p/Relationship#as_simple.md)).

# SEE ALSO

[REST::Neo4p](/lib/REST/Neo4p.md), [REST::Neo4p::Node](/lib/REST/Neo4p/Node.md), [REST::Neo4p::Relationship](/lib/REST/Neo4p/Relationship.md),
[REST::Neo4p::Query](/lib/REST/Neo4p/Query.md).

# AUTHOR

    Mark A. Jensen
    CPAN ID: MAJENSEN
    majensen -at- cpan -dot- org

# LICENSE

Copyright (c) 2012-2020 Mark A. Jensen. This program is free software; you
can redistribute it and/or modify it under the same terms as Perl
itself.
