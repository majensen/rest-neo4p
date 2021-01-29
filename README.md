![test](https://github.com/majense/rest-neo4p/workflows/test-rest-neo4p/badge.svg)

# NAME

REST::Neo4p - Perl object bindings for a Neo4j database

# SYNOPSIS

     use REST::Neo4p;
     REST::Neo4p->connect('http://127.0.0.1:7474');
     $i = REST::Neo4p::Index->new('node', 'my_node_index');
     $i->add_entry(REST::Neo4p::Node->new({ name => 'Fred Rogers' }),
                                          guy  => 'Fred Rogers');
     $index = REST::Neo4p->get_index_by_name('my_node_index','node');
    ($my_node) = $index->find_entries('guy' => 'Fred Rogers');
     $new_neighbor = REST::Neo4p::Node->new({'name' => 'Donkey Hoty'});
     $my_reln = $my_node->relate_to($new_neighbor, 'neighbor');

     $query = REST::Neo4p::Query->new("MATCH p = (n)-[]->()
                                       WHERE id(n) = \$id
                                       RETURN p", { id => $my_node->id });
     $query->execute;
     $path = $query->fetch->[0];
     @path_nodes = $path->nodes;
     @path_rels = $path->relationships;

Batch processing (see [REST::Neo4p::Batch](/lib/REST/Neo4p/Batch.md) for more)

_Not available for Neo4j v4.0+_

    #!perl
    # loader...
    use REST::Neo4p;
    use REST::Neo4p::Batch;
    
    open $f, shift() or die $!;
    batch {
      while (<$f>) {
       chomp;
       ($name, $value) = split /\t/;
       REST::Neo4p::Node->new({name => $name, value => $value});
      } 'discard_objs';
    exit(0);

# DESCRIPTION

REST::Neo4p provides a Perl 5 object framework for accessing and
manipulating a [Neo4j](http://neo4j.org) graph database server via the
Neo4j REST API. Its goals are

(1) to make the API as transparent as possible, allowing the user to
work exclusively with Perl objects, and

(2) to exploit the API's self-discovery mechanisms, avoiding as much
as possible internal hard-coding of URLs.

**Neo4j version 4.0+**: The REST API and the "cypher endpoint" are no
longer found in Neo4j servers after version 3.5. Never fear: the
`Neo4j::Driver` user agent, based on AJNN's [Neo4j::Driver](https://metacpan.org/pod/Neo4j::Driver),
emulates both of these deprecated endpoints for REST::Neo4p. The goal
is that REST::Neo4p will plug and play with version 4.0+. Be sure to
report any bugs.

Neo4j entities are represented by corresponding classes:

- Nodes : [REST::Neo4p::Node](/lib/REST/Neo4p/Node.md)
- Relationships : [REST::Neo4p::Relationship](/lib/REST/Neo4p/Relationship.md)
- Indexes : [REST::Neo4p::Index](/lib/REST/Neo4p/Index.md)

Actions on class instances have a corresponding effect on the database
(i.e., REST::Neo4p approximates an ORM).

The class [REST::Neo4p::Query](/lib/REST/Neo4p/Query.md) provides a DBIesqe Cypher query facility.
(And see also [DBD::Neo4p](https://metacpan.org/pod/DBD::Neo4p).)

## Property Auto-accessors

Depending on the application, it may be natural to think of properties
as fields of your nodes and relationships. To create accessors named
for the entity properties, set

    $REST::Neo4p::CREATE_AUTO_ACCESSORS = 1;

Then, when [set\_property()](/lib/REST/Neo4p/Node#set_property.md) is used
to first create and set a property, accessors will be created on the
class:

    $node1->set_property({ flavor => 'strange', spin => -0.5 });
    printf "Quark has flavor %s\n", $node1->flavor;
    $node1->set_spin(0.5);

If your point of reference is the database, rather than the objects,
auto-accessors may be confusing, since once the accessor is created
for the class, it will exist for all future instances:

    print "Yes I can!\n" if REST::Neo4p::Node->new()->can('flavor');

but there is no fundamental reason why new nodes or relationships must
have the property (it is NoSQL, after all). Therefore this is a choice
for you to make; the default is _no_ auto-accessors.

## Application-level constraints

[REST::Neo4p::Constrain](/lib/REST/Neo4p/Constrain.md) provides a flexible means for creating,
enforcing, serializing and loading property and relationship
constraints on your database through REST::Neo4p. It allows you, for
example, to specify "kinds" of nodes based on their properties,
constrain properties and the values of properties for those nodes, and
then specify allowable relationships between kinds of nodes.

Constraints can be enforced automatically, causing exceptions to be
thrown
 when constraints are violated. Alternatively, you can use
validation functions to test properties and relationships, including
those already present in the database.

This is a mixin that is not _use_d automatically by REST::Neo4p. For
details and examples, see [REST::Neo4p::Constrain](/lib/REST/Neo4p/Constrain.md) and
[REST::Neo4p::Constraint](/lib/REST/Neo4p/Constraint.md).

## Server-side constraints (Neo4j server version 2.0.1+)

Neo4j ["schema" constraints](http://docs.neo4j.org/chunked/stable/cypher-schema.html)
based on labels can be manipulated via REST using
[REST::Neo4p::Schema](/lib/REST/Neo4p/Schema.md).

# USER AGENT

The backend user agent can be selected by setting the package variable
`$REST::Neo4p::AGENT_MODULE` to one of the following

    LWP::UserAgent
    Mojo::UserAgent
    HTTP::Thin
    Neo4j::Driver

The [REST::Neo4p::Agent](/lib/REST/Neo4p/Agent.md) created will be a subclass of the selected
backend agent. It can be accessed with ["agent()"](#agent).

The initial value of `$REST::Neo4p::AGENT_MODULE` will be the value
of the environment variable `REST_NEO4P_AGENT_MODULE` or
`LWP::UserAgent` by default.

If your Neo4j database is version 4.0 or greater, `Neo4j::Driver`
will be used automatically and a warning will ensue if this overrides
a different choice.

# CLASS METHODS

- connect()

        REST::Neo4p->connect( $server );
        REST::Neo4p->connect( $server, $user, $pass );

- agent()

        REST::Neo4p->agent->credentials( $server, 'Neo4j', $user, $pass);
        REST::Neo4p->connect($server);

    Returns the underlying [REST::Neo4p::Agent](/lib/REST/Neo4p/Agent.md) object.

- neo4j\_version()

        $version_string = REST::Neo4p->neo4j_version;
        ($major, $minor, $patch, $milestone) = REST::Neo4p->neo4j_version;

    Returns the server's neo4j version string/components, or undef if not connected.

- get\_node\_by\_id()

        $node = REST::Neo4p->get_node_by_id( $id );

    Returns false if node `$id` does not exist in database.

- get\_relationship\_by\_id()

        $relationship = REST::Neo4p->get_relationship_by_id( $id );

    Returns false if relationship `$id` does not exist in database.

- get\_index\_by\_name()

        $node_index = REST::Neo4p->get_index_by_name( $name, 'node' );
        $relationship_index = REST::Neo4p->get_index_by_name( $name, 'relationship' );

    Returns false if index `$name` does not exist in database.

- get\_relationship\_types()

        @all_relationship_types = REST::Neo4p->get_relationship_types;

- get\_indexes(), get\_node\_indexes(), get\_relationship\_indexes()

        @all_indexes = REST::Neo4p->get_indexes;
        @node_indexes = REST::Neo4p->get_node_indexes;
        @relationship_indexes = REST::Neo4p->get_relationship_indexes;

## Label Support (Neo4j version 2.0+)

- get\_nodes\_by\_label()

        @nodes = REST::Neo4p->get_nodes_by_label( $label );
        @nodes = REST::Neo4p->get_nodes_by_label($label, $property => $value );

    Returns false if no nodes with given label in database.

- get\_all\_labels()

        @graph_labels = REST::Neo4p->get_all_labels;

## Transaction Support (Neo4j version 2.0+)

Initiate, commit, or rollback [queries](/lib/REST/Neo4p/Query.md) in transactions.

- begin\_work()
- commit()
- rollback()

        $q = REST::Neo4p::Query->new(
          'match (n)-[r:pal]->(m) where id(n)=0 create r'
        );
        $r = REST::Neo4p::Query->new(
           'match (n)-[r:pal]->(u) where id(n)=0 merge u'
        );
        REST::Neo4p->begin_work;
        $q->execute;
        $r->execute;
        if ($q->err || $r->err) {
          REST::Neo4p->rollback;
        }
        else {
          REST::Neo4p->commit;
          $results = REST::Neo4p->_tx_results;
          unless (REST::Neo4p->_tx_errors) {
            print 'all queries successful';
          }
        }

- \_tx\_results(), \_tx\_errors()

    These fields contain decoded JSON responses from the server following
    a commit.  `_tx_errors` is an arrayref of statement errors during
    commit. `_tx_results` is an arrayref of columns-data hashes as
    described at
    [Neo4j:Transactional HTTP endpoint](http://docs.neo4j.org/chunked/stable/rest-api-transactional.html).

    These fields are cleared by `begin_work()` and `rollback()`.

# SEE ALSO

[REST::Neo4p::Node](/lib/REST/Neo4p/Node.md),[REST::Neo4p::Relationship](/lib/REST/Neo4p/Relationship.md),[REST::Neo4p::Index](/lib/REST/Neo4p/Index.md),
[REST::Neo4p::Query](/lib/REST/Neo4p/Query.md), [REST::Neo4p::Path](/lib/REST/Neo4p/Path.md), [REST::Neo4p::Batch](/lib/REST/Neo4p/Batch.md),
[REST::Neo4p::Schema](/lib/REST/Neo4p/Schema.md),[REST::Neo4p::Constrain](/lib/REST/Neo4p/Constrain.md), [REST::Neo4p::Constraint](/lib/REST/Neo4p/Constraint.md).

# AUTHOR

    Mark A. Jensen
    CPAN ID: MAJENSEN
    majensen -at- cpan -dot- org

# LICENSE

Copyright (c) 2012-2020 Mark A. Jensen. This program is free software; you
can redistribute it and/or modify it under the same terms as Perl
itself.
