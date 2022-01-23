# NAME

REST::Neo4p::Agent - HTTP client interacting with Neo4j

# SYNOPSIS

    $agent = REST::Neo4p::Agent->new();
    $agent->server_url('http://127.0.0.1:7474');
    unless ($agent->connect) {
     print STDERR "Didn't find the server\n";
    }

See examples under ["METHODS"](#methods) below.

# DESCRIPTION

The agent's job is to encapsulate and connect to the REST service URLs
of a running Neo4j server. It also stores the discovered URLs for
various actions and provides those URLs as getters from the agent
object. The getter names are the keys in the JSON objects returned by
the server. See
[the Neo4j docs](http://docs.neo4j.org/chunked/stable/rest-api.html) for more
details.

API and HTTP errors are distinguished and thrown by
[Exception::Class](https://metacpan.org/pod/Exception::Class) subclasses. See [REST::Neo4p::Exceptions](/lib/REST/Neo4p/Exceptions.md).

A REST::Neo4p::Agent instance is created as a subclass of a choice
of HTTP user agents:

- [LWP::UserAgent](https://metacpan.org/pod/LWP::UserAgent) (default)
- [Mojo::UserAgent](https://metacpan.org/pod/Mojo::UserAgent)
- [HTTP::Thin](https://metacpan.org/pod/HTTP::Thin) ([HTTP::Tiny](https://metacpan.org/pod/HTTP::Tiny) with [HTTP::Response](https://metacpan.org/pod/HTTP::Response) responses)

REST::Neo4p::Agent responses are always [HTTP::Response](https://metacpan.org/pod/HTTP::Response) objects.

REST::Neo4p::Agent will retry requests that fail with
[REST::Neo4p::CommException](/lib/REST/Neo4p/Exceptions.md). The default
number of retries is 3; the default wait time between retries is 5
sec. These can be adjusted by setting the package variables

    $REST::Neo4p::Agent::RQ_RETRIES
    $REST::Neo4p::Agent::RETRY_WAIT

to the desired values.

According to the Neo4j recommendation, the agent requests streamed
responses by default; i.e.,

    X-Stream: true

is a default header for requests. The server responds to requests with
chunked content, which is handled correctly by any of the underlying
user agents.

[REST::Neo4p::Query](/lib/REST/Neo4p/Query.md) and [REST::Neo4p::Batch](/lib/REST/Neo4p/Batch.md) take advantage of
streamed responsed by retrieving and returning JSON objects
incrementally and (with the [Mojo::UserAgent](https://metacpan.org/pod/Mojo::UserAgent) backend) in a
non-blocking way. New Neo4j server versions may break the incremental
parsing. If this happens,  [make a
ticket](https://rt.cpan.org/Public/Bug/Report.html?Queue=REST-Neo4p). In
the meantime, you should be able to keep things going (albeit more
slowly) by turning off streaming at the agent:

    REST::Neo4p->agent->no_stream;

Streaming responses can be requested again by issuing

    REST::Neo4p->agent->stream

For batch API features, see ["Batch Mode"](#batch-mode).

# METHODS

- new()

        $agent = REST::Neo4p::Agent->new();
        $agent = REST::Neo4p::Agent->new( agent_module => 'HTTP::Thin');
        $agent = REST::Neo4p::Agent->new("http://127.0.0.1:7474");

    Returns a new agent. The `agent_module` parameter may be set to

        LWP::UserAgent (default)
        Mojo::UserAgent
        HTTP::Thin

    to select the underlying user agent class. Additional arguments are
    passed to the user agent constructor.

- server\_url()

        $agent->server_url("http://127.0.0.1:7474");

    Sets the server address and port.

- data()

        $neo4j_data_url = $agent->data();

    Returns the base of the Neo4j server API.

- admin()

        $neo4j_admin_url = $agent->admin();

    Returns the Neo4j server admin url.

- node()
- reference\_node()
- node\_index()
- relationship\_index()
- extensions\_info()
- relationship\_types()
- batch()
- cypher()

        $relationship_type_url = $agent->relationship_types;

    These methods get the REST URL for the named API actions. Other named
    actions may also be available for a given server; these are
    auto-loaded from self-discovery responses provided by Neo4j. Use
    `available_actions()` to identify them.

    You will probably prefer using the ["get\_{action}()"](#get_-action),
    ["put\_{action}()"](#put_-action), ["post\_{action}()"](#post_-action), and ["delete\_{action}()"](#delete_-action)
    methods to make requests directly.

- neo4j\_version()

        $version = $agent->neo4j_version;
        ($major, $minor, $patch, $milestone) = $agent->neo4j_version;

    Returns the version string/components of the connected Neo4j server.

- available\_actions()

        @actions = $agent->available_actions();

    Returns all discovered actions.

- location()

        $agent->post_node(); # create new node
        $new_node_url = $agent->location;

    Returns the value of the "location" key in the response JSON. 

- get\_{action}()

        $decoded_response = $agent->get_data(@url_components,\%rest_params)
        $types_array_ref = $agent->get_relationship_types();

    Makes a GET request to the REST endpoint mapped to {action}. Arguments
    are additional URL components (without slashes). If the final argument
    is a hashref, it will be sent as key-value form parameters.

- put\_{action}()

        # add a property to an existing node
        $agent->put_node([13, 'properties'], { name => 'Herman' });

    Makes a PUT request to the REST endpoint mapped to {action}. The first
    argument, if present, must be an array **reference** of additional URL
    components. The second argument, if present, is a hashref that will be
    sent in the request as (encoded) JSON content. The third argument, if 
    present, is a hashref containing additional request headers.

- post\_{action}()

        # create a new node with given properties
        $agent->post_node({ name => 'Wanda' });
        # do a cypher query and save content to file
        $agent->post_cypher([], { query => 'MATCH (n) RETURN n', params=>{}},
                            { ':content_file' => $my_file_name });

    Makes a POST request to the REST endpoint mapped to {action}. The first
    argument, if present, must be an array **reference** of additional URL
    components. The second argument, if present, is a hashref that will be
    sent in the request as (encoded) JSON content. The third argument, if 
    present, is a hashref containing additional request headers.

- delete\_{action}()

        $agent->delete_node(13);
        $agent->delete_node_index('myindex');

    Makes a DELETE request to the REST endpoint mapped to {action}. Arguments
    are additional URL components (without slashes). If the final argument
    is a hashref, it will be sent in the request as (encoded) JSON content.

- decoded\_content()

        $decoded_json = $agent->decoded_content;

    Returns the response content of the last agent request, as decoded by
    [JSON](https://metacpan.org/pod/JSON). It is generally a reference, but can be a scalar if a
    bareword was returned by the server.

- raw\_response()

        $resp = $agent->raw_response

    Returns the [HTTP::Response](https://metacpan.org/pod/HTTP::Response) object returned by the last request made
    by the backend user agent.

- no\_stream()

        $agent->no_stream;

    Removes `X-Stream: true` from the default headers.

- stream()

        $agent->stream;

    Adds `X-Stream: true` to the default headers.

# Batch Mode

**Neo4j version 4.0+**: _Batch mode is a Neo4j REST API feature that bit
the big one along with that API. The Neo4j::Driver agent will complain
if you use these methods._

When the agent is in batch mode, the usual request calls are not
executed immediately, but added to a queue. The ["execute\_batch()"](#execute_batch)
method sends the queued calls in the format required by the Neo4p REST
API (using the `post_batch` method outside of batch
mode). ["execute\_batch()"](#execute_batch) returns the decoded json server response in
the return format specified by the Neo4p REST batch API.

- batch\_mode()

        print ($agent->batch_mode ? "I am " : "I am not ")." in batch mode\n";
        $agent->batch_mode(1);

    Set/get current agent mode.

- batch\_length()

        if ($agent->batch_length() > $JOB_LIMIT) {
          print "Queue getting long; better execute\n"
        }

    Returns current queue length. Throws
    [REST::Neo4p::LocalException](/lib/REST/Neo4p/Exceptions.md) if agent not in
    batch mode.

- execute\_batch()

        $tmpfh = $agent->execute_batch();
        $tmpfh = $agent->execute_batch(50);

        while (<$tmpfn>) {
          # handle responses
        }

    Processes the queued calls and returns the decoded json response from
    server in a temporary file. Returns with undef if batch length is zero.
    Throws [REST::Neo4p::LocalException](/lib/REST/Neo4p/Exceptions.md) if not in batch mode.

    Second form takes an integer argument; this will submit the next \[integer\]
    jobs and return the server response in the tempfile. The batch length is
    updated.

    The filehandle returned is a [File::Temp](https://metacpan.org/pod/File::Temp) object. The file will be unlinked
    when the object is destroyed.

- execute\_batch\_chunk()

        while (my $tmpf = $agent->execute_batch_chunk ) {
         # handle response
        }

    Convenience form of
    `execute_batch($REST::Neo4p::JOB_CHUNK)`. `$REST::Neo4p::JOB_CHUNK`
    has default value of 1024.

# AUTHOR

    Mark A. Jensen
    CPAN ID: MAJENSEN
    majensen -at- cpan -dot- org

# LICENSE

Copyright (c) 2012-2022 Mark A. Jensen. This program is free software; you
can redistribute it and/or modify it under the same terms as Perl
itself.
