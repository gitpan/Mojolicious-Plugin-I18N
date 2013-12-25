#!/usr/bin/env perl
use lib qw(lib ../lib ../mojo/lib ../../mojo/lib);
use utf8;

use Mojo::Base -strict;

# Disable Bonjour, IPv6 and libev
BEGIN {
  $ENV{MOJO_NO_BONJOUR} = $ENV{MOJO_NO_IPV6} = 1;
  $ENV{MOJO_IOWATCHER} = 'Mojo::IOWatcher';
}

use Test::More;

package App::I18N;
use base 'Locale::Maketext';

package App::I18N::en;
use Mojo::Base 'App::I18N';

our %Lexicon = (_AUTO => 1, hello2 => 'Hello two');

package App::I18N::ru;
use Mojo::Base 'App::I18N';

our %Lexicon = (hello => 'Привет', hello2 => 'Привет два');

package main;
use Mojolicious::Lite;

use Test::Mojo;

# I18N plugin
plugin 'I18N' => { namespace => 'App::I18N', default => 'ru', support_url_langs => [qw(ru en de)] };

get '/' => 'index';
get '/auth' => 'auth';

post '/login' => sub {
  my $self = shift;
  
  # Do login things ;)
  # ...
  
  return $self->redirect_to($self->param('next') || 'index');
};

#

my $t = Test::Mojo->new;

$t->get_ok('/')->status_is(200)
  ->content_is("ПриветПривет дваru\n/\n/?test=1\n");

$t->get_ok('/ru')->status_is(200)
  ->content_is("ПриветПривет дваru\n/ru\n/ru?test=1\n");

$t->get_ok('/en')->status_is(200)
  ->content_is("helloHello twoen\n/en\n/en?test=1\n");

$t->get_ok('/de')->status_is(200)
  ->content_is("ПриветПривет дваru\n/de\n/de?test=1\n");

$t->get_ok('/es')->status_is(404);

my $port = $t->tx->remote_port();

$t->get_ok('/auth')->status_is(200)
  ->content_is(qq{<a href="http://example.com/widget?lang=ru&token_url=http://localhost:$port/login?next=/auth">auth</a>\n});

$t->post_ok('/login?next=/auth')->status_is(302)
  ->header_is('Location' => "http://localhost:$port/auth");

$t->get_ok('/ru/auth')->status_is(200)
  ->content_is(qq{<a href="http://example.com/widget?lang=ru&token_url=http://localhost:$port/ru/login?next=/ru/auth">auth</a>\n});

$t->post_ok('/login?next=/ru/auth')->status_is(302)
  ->header_is('Location' => "http://localhost:$port/ru/auth");

$t->get_ok('/en/auth')->status_is(200)
  ->content_is(qq{<a href="http://example.com/widget?lang=en&token_url=http://localhost:$port/en/login?next=/en/auth">auth</a>\n});

$t->post_ok('/login?next=/en/auth')->status_is(302)
  ->header_is('Location' => "http://localhost:$port/en/auth");

$t->post_ok('/login?next=/es/auth')->status_is(302)
  ->header_is('Location' => "http://localhost:$port/es/auth");

$t->post_ok('/login?next=/ru/en/auth')->status_is(302)
  ->header_is('Location' => "http://localhost:$port/ru/en/auth");

$t->post_ok('/login?next=/english/auth')->status_is(302)
  ->header_is('Location' => "http://localhost:$port/english/auth");

done_testing;

__DATA__
@@ index.html.ep
<%=l 'hello' %><%=l 'hello2' %><%= languages %>
%= url_for
%= url_for->query(test => 1)

@@ auth.html.ep
<a href="http://example.com/widget?lang=<%= languages %>&token_url=<%= url_for('login')->query('next' => url_for 'auth')->to_abs() %>">auth</a>
