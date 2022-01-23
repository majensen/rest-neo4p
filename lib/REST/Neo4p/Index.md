# NAME

REST::Neo4p::Index - Neo4j index object

# SYNOPSIS

    $node_idx = REST::Neo4p::Index->new('node', 'my_node_index');
    $rel_idx = REST::Neo4p::Index->new('relationship', 'my_rel_index');
    $fulltext_idx = REST::Neo4p::Index->new('node', 'my_ft_index',
                                       { type => 'fulltext',
                                         provider => 'lucene' });
    $node_idx->add_entry( $ShaggyNode, 'pet' => 'ScoobyDoo' );
    $node_idx->add_entry( $ShaggyNode,
      'pet' => 'ScoobyDoo',
      'species' => 'Dog',
      'genotype' => 'ScSc',
      'episodes_featured' => 2343 );

    @returned_nodes = $node_idx->find_entries('pet' => 'ScoobyDoo');
    @returned_nodes = $node_idx->find_entries('pet:Scoob*');
    $node_idx->remove_entry( $JosieNode, 'hair' => 'red' );

# DESCRIPTION

REST::Neo4p::Index objects represent Neo4j node and relationship indexes.

# USAGE NOTE - VERSION 4.0

_TL;DR - Using indexes in REST::Neo4p on Neo4j 4.0 should just work._

Index objects were originally designed to encapsulate Neo4j "explicit"
indexes, which map nodes/relationships to a key-value pair.

As of Neo4j version 4.0, explicit indexes are not supported. Since
there may be applications using REST::Neo4p depending on the Index
functionality, the agent based on [Neo4j::Driver](https://metacpan.org/pod/Neo4j::Driver) uses fulltext
indexes under the hood to emulate explicit indexes. This agent is used
automatically with Neo4j version 4.0 servers.

# METHODS

- new()

        $node_idx = REST::Neo4p::Index->new('node', 'my_node_index');
        $rel_idx = REST::Neo4p::Index->new('relationship', 'my_rel_index');
        $fulltext_idx = REST::Neo4p::Index->new('node', 'my_ft_index',
                                           { type => 'fulltext',
                                             provider => 'lucene' });
        # Neo4j 4.0+
        $rel_idx = REST::Neo4p::Index->new('relationship', 'my_rel_index', {rtype => "my_reln_type"});

    Creates a new index of the type given in the first argument, with the
    name given in the second argument. The optional third argument is a
    hashref containing an index configuration as provided for in the Neo4j
    API.

    _Note_: For Neo4j 4.0+, REST::Neo4p emulates an explicit index using a
    fulltext index. Fulltext indexes on relationships require specifying a
    relationship type. To do this, include the key `rtype` in the third
    argument hashref.

- remove()

        $index->remove()

    **CAUTION**: This method removes the index from the database and destroys the object.

- name()

        $idx_name = $index->name()

- type()

        if ($index->type eq 'node') { $index->add_entry( $node, $key => $value ); }

- add\_entry()

        $index->add_entry( $node, $key => $value );
        $index->add_entry( $node, $key1 => $value1, $key2 => $value2,...);
        $index->add_entry( $node, $key_value_hashref );

- remove\_entry()

        $index->remove_entry($node);
        $index->remove_entry($node, $key);
        $index->remove_entry($node, $key => $value);

- find\_entries()

        @returned_nodes = $node_index->find_entries($key => $value);
        @returned_rels = $rel_index->find_entries('pet:Scoob*');

    In the first form, an exact match is sought. In the second (i.e., when
    a single string argument is passed), the argument is interpreted as a
    query string and passed to the index as such. The Neo4j default is
    [Lucene](http://lucene.apache.org/core/3_5_0/queryparsersyntax.html).

    `find_entries()` is not supported in batch mode.

- create\_unique()

        $node = $index->create_unique( name => 'fred', 
                                       { name => 'fred', state => 'unshaven'} );

        $reln = $index->create_unique( name => 'married_to',
                                       $node => $wilma_node,
                                       'MARRIED_TO');

    Creates a unique node or relationship on the basis of presence or absence
    of a matching item in the index. 

    Optional final argument: one of 'get' or 'fail'. If 'get' (default), the 
    matching item is returned if present. If 'fail', false is returned.

# SEE ALSO

[REST::Neo4p](/lib/REST/Neo4p.md), [REST::Neo4p::Relationship](/lib/REST/Neo4p/Relationship.md), [REST::Neo4p::Node](/lib/REST/Neo4p/Node.md).

# AUTHOR

    Mark A. Jensen
    CPAN ID: MAJENSEN
    majensen -at- cpan -dot- org

# LICENSE

Copyright (c) 2012-2022 Mark A. Jensen. This program is free software; you
can redistribute it and/or modify it under the same terms as Perl
itself.
