#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Plack::Test;

use Test::Requires 'HTTP::Throwable::Factory';

{
    package Foo::Middleware;
    use Moose;
    use MooseX::NonMoose;

    extends 'Plack::Middleware';

    sub call {
        my $self = shift;
        my ($env) = @_;

        my $req = OX::Request->new($env);
        my $uri = $req->uri_for({name => 'root'});
        my $res = $self->app->($env);
        $res->[2][0] .= " " . $uri;

        return $res;
    }
}

{
    package Foo;
    use OX;

    router as {
        wrap 'Foo::Middleware';
        route '/' => sub { "root" } => (
            name => 'root',
        );
    }
}

test_psgi
    app    => Foo->new->to_app,
    client => sub {
        my $cb = shift;
        {
            my $req = HTTP::Request->new(GET => 'http://localhost/');
            my $res = $cb->($req);
            is($res->content, 'root /');
        }
    };

{
    package Bar::Middleware;
    use Moose;
    use MooseX::NonMoose;

    use HTTP::Throwable::Factory 'http_throw';

    extends 'Plack::Middleware';

    sub call {
        my $self = shift;
        my ($env) = @_;

        http_throw('NotAcceptable');
    }
}

{
    package Bar;
    use OX;

    router as {
        wrap 'Bar::Middleware';
        route '/' => sub { "root" };
    }
}

test_psgi
    app    => Bar->new->to_app,
    client => sub {
        my $cb = shift;
        {
            my $req = HTTP::Request->new(GET => 'http://localhost/');
            my $res = $cb->($req);
            is($res->code, 406);
        }
    };

done_testing;
