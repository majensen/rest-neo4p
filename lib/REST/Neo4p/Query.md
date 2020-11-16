# NAME

REST::Neo4p::Query - Execute Neo4j Cypher queries

# SYNOPSIS

    REST::Neo4p->connect('http:/127.0.0.1:7474');
    $query = REST::Neo4p::Query->new('MATCH (n) WHERE n.name = "Boris" RETURN n');
    $query->execute;
    $node = $query->fetch->[0];
    $node->relate_to($other_node, 'link');

# DESCRIPTION

REST::Neo4p::Query encapsulates Neo4j Cypher language queries,
executing them via [REST::Neo4p::Agent](/lib/REST/Neo4p/Agent.md) and returning an iterator
over the rows, in the spirit of [DBI](https://metacpan.org/pod/DBI).

## Streaming

[`execute()`](#execute) captures the Neo4j query response in a temp
file. [`fetch()`](#fetch) iterates (in a non-blocking way if
possible) over the JSON in the response using the incremental parser
of [JSON::XS](https://metacpan.org/pod/JSON::XS) (see [REST::Neo4p::ParseStream](/lib/REST/Neo4p/ParseStream.md) if
interested). So go ahead and make those 100 meg queries. The tempfile
is unlinked after the iterator runs out of rows, or upon object
destruction, whichever comes first.

## Parameters

`REST::Neo4p::Query` understands Cypher [query
parameters](http://docs.neo4j.org/chunked/stable/cypher-parameters.html). These
are represented in Cypher, unfortunately, as dollar-prefixed tokens.

    MATCH (n) WHERE n.first_name = $name RETURN n

Here, `$name` is the named parameter. 

Don't forget to escape the dollar sign if you're also doing string interpolation:

    $prop = "n.name";
    $qry = "MATCH (n) WHERE $prop = \$name RETURN n";
    

A single query object can be executed multiple times with different parameter values:

    my $q = REST::Neo4p::Query->new(
              'MATCH (n) WHERE n.first_name = $name RETURN n'
            );
    foreach (@names) {
      $q->execute(name => $_);
      while ($row = $q->fetch) {
       ...process
      }
    }

This is very highly recommended over creating multiple query objects like so:

    foreach (@names) {
      my $q = REST::Neo4p::Query->new(
                "MATCH (n) WHERE n.first_name = '$_' RETURN n"
              );
      $q->execute;
      ...
    }

As with any database engine, a large amount of overhead is saved by
planning a parameterized query once. In addition, the REST side of the
Neo4j server will balk at handling 1000s of individual queries in a row.
Parameterizing queries gets around this issue.

## Paths

If your query returns a path, [`fetch()`](#fetch) returns a
[REST::Neo4p::Path](/lib/REST/Neo4p/Path.md) object from which you can obtain the Nodes and
Relationships.

## Transactions

See ["Transaction Support (Neo4j Version 2.0+)" in REST::Neo4p](/lib/REST/Neo4p#Transaction-Support-Neo4j-Version-2.0.md).

# METHODS

- new()

        $stmt = 'MATCH (n) WHERE id(n) = $node_id RETURN n';
        $query = REST::Neo4p::Query->new($stmt,{node_id => 1});

    Create a new query object. First argument is the Cypher query
    (required). Second argument is a hashref of parameters (optional).

- execute()

        $numrows = $query->execute;
        $numrows = $query->execute( param1 => 'value1', param2 => 'value2');
        $numrows = $query->execute( $param_hashref );

    Execute the query on the server. Not supported in batch mode.

- fetch()
- fetchrow\_arrayref()

        $query = REST::Neo4p::Query->new('MATCH (n) RETURN n, n.name LIMIT 10');
        $query->execute;
        while ($row = $query->fetch) { 
          print 'It works!' if ($row->[0]->get_property('name') == $row->[1]);
        }

    Fetch the next row of returned data (as an arrayref). Nodes are
    returned as [REST::Neo4p::Node](/lib/REST/Neo4p/Node.md) objects,
    relationships are returned as
    [REST::Neo4p::Relationship](/lib/REST/Neo4p/Relationship.md) objects,
    scalars are returned as-is.

- err(), errstr(), errobj()

        $query->execute;
        if ($query->err) {
          printf "status code: %d\n", $query->err;
          printf "error message: %s\n", $query->errstr;
          printf "Exception class was %s\n", ref $query->errobj;
        }

    Returns the HTTP error code, Neo4j server error message, and exception
    object if an error was encountered on execution.

- err\_list()
- finish()

        while (my $row = $q->fetch) {
          if ($row->[0] eq 'What I needed') {
            $q->finish();
            last;
          }
        }

    Call finish() to unlink the tempfile before all items have been
    fetched.

## ATTRIBUTES

- RaiseError

        $q->{RaiseError} = 1;

    Set `$query->{RaiseError}` to die immediately (e.g., to catch the exception in an `eval` block).

- ResponseAsObjects

        $q->{ResponseAsObjects} = 0;
        $row_as_plain_perl = $q->fetch;

    If set to true (the default), query reponses are returned as
    REST::Neo4p objects.  If false, nodes, relationships and paths are
    returned as simple perl structures.  See
    ["as\_simple()" in REST::Neo4p::Node](/lib/REST/Neo4p/Node#as_simple.md),
    ["as\_simple()" in REST::Neo4p::Relationship](/lib/REST/Neo4p/Relationship#as_simple.md),
    ["as\_simple()" in REST::Neo4p::Path](/lib/REST/Neo4p/Path#as_simple.md) for details.

- Statement

        $stmt = $q->{Statement};

    Get the Cypher statement associated with the query object.

# SEE ALSO

[DBD::Neo4p](https://metacpan.org/pod/DBD::Neo4p), [REST::Neo4p](/lib/REST/Neo4p.md), [REST::Neo4p::Path](/lib/REST/Neo4p/Path.md), [REST::Neo4p::Agent](/lib/REST/Neo4p/Agent.md).

# AUTHOR

    Mark A. Jensen
    CPAN ID: MAJENSEN
    majensen -at- cpan -dot- org

# LICENSE

Copyright (c) 2012-2020 Mark A. Jensen. This program is free software; you
can redistribute it and/or modify it under the same terms as Perl
itself.
