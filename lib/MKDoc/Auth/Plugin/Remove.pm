=head1 NAME

MKDoc::Auth::Plugin::Remove - Let users remove their own accounts.


=head1 SUMMARY

This module lets users delete themselves.


=head1 INHERITS FROM

L<MKDoc::Auth::Plugin::Edit>

=cut
package MKDoc::Auth::Plugin::Remove;
use MKDoc::Auth::User;
use strict;
use warnings;
use base qw /MKDoc::Auth::Plugin::Edit/;


=head2 $self->uri_hint();

Helps deciding what the URI of this plugin should be.

By default, returns 'edit.html'.

Can be overriden by setting the MKD__AUTH_DELETE_URI_HINT environment variable or
by subclassing.

=cut
sub uri_hint
{
    return $ENV{MKD__AUTH_DELETE_URI_HINT} || 'remove.html';
}


=head2 $self->http_post();

Deletes the user and redirects to $self->return_uri().

=cut
sub http_post
{
    my $self = shift;
    my $req  = $self->request();
    my $obj  = $self->object();
    $obj->delete();

    print $req->redirect ($self->return_uri());
    return 'TERMINATE';
}


1;
