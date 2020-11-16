# NAME

REST::Neo4p::ParseStream - Parse Neo4j REST responses on the fly

# SYNOPSIS

    Not for human consumption.
    This module is ignored by the Neo4j::Driver-based agent.

# DESCRIPTION

This module helps [REST::Neo4p](/lib/REST/Neo4p.md) exploit the [Neo4j](http://neo4j.org)
server's chunked transfer encoding of its JSON REST responses. It is
based on the fast [JSON::XS](https://metacpan.org/pod/JSON::XS) incremental parser and
[MJD](https://metacpan.org/author/MJD)'s [Higher Order
Perl](http://hop.perl.plover.com) ideas as implemented in
[HOP::Stream](https://metacpan.org/pod/HOP::Stream).

The goal is to be able to pull in objects from the server stream as
soon as they are available. In practice, this means specifically
finding and incrementally processing the potentially large arrays of
objects that are returned from cypher queries, transaction queries,
and batch requests.

Because of inconsistencies among the Neo4j response formats for each
of these functions, this module does a significant amount of
"hand-parsing". Currently the code will not be very robust to changes
in those response formats. If you find your query handling is breaking
with a new server version, [make a
ticket](https://rt.cpan.org/Public/Bug/Report.html?Queue=REST-Neo4p). In
the meantime, you should be able to keep things going (albeit more
slowly) by turning off streaming at the agent:

    use REST::Neo4p;
    REST::Neo4p->agent->no_stream;
    ...

# SEE ALSO

[REST::Neo4p](/lib/REST/Neo4p.md), [REST::Neo4p::Query](/lib/REST/Neo4p/Query.md), [REST::Neo4p::Batch](/lib/REST/Neo4p/Batch.md),
[HOP::Stream](https://metacpan.org/pod/HOP::Stream), ["INCREMENTAL PARSING" in JSON::XS](https://metacpan.org/pod/JSON::XS#INCREMENTAL-PARSING).

# AUTHOR

    Mark A. Jensen
    CPAN ID: MAJENSEN
    majensen -at- cpan -dot- org

# LICENSE

Copyright (c) 2012-2020 Mark A. Jensen. This program is free software; you
can redistribute it and/or modify it under the same terms as Perl
itself.
