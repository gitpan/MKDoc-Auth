=head1 NAME

MKDoc::Auth::Plugin::Login


=head1 SUMMARY

This plugin lets a user login, logout, or login as somebody else. All in one!

When /.login.html is invoked, it computes a timestamp in the near future (+5s
or something) and immediately redirects the user to /.login.html?<timestamp>.

When the first request to /.login.html?<timestamp> comes, the time is still
less than <timestamp>. Hence the plugin sets HTTP headers which will cause the
web browser to display a form to input user credentials.

  $stamp and time < $stamp and do {
      $::MKD_USER = undef;
      my $rsp = $self->response();
      $rsp->Status ("401 Authorization Required");
      $rsp->WWW_Authenticate ('Basic realm="MKDoc/Auth 0.1"');
  };

If the user chooses to click 'cancel', it immediately discards their user
credentials and they are de-facto logged out.

If the user chooses to enter their username and password, it will trigger
another request to /.login.html?<timestamp>, with the user credentials.

Except that by the time the user has entered his credentials, <timestamp> will
be in the past, not in the future anymore. Hence the credentials will not be
re-requested and the user will be logged in.


=head1 INHERITS FROM

L<MKDoc::Core::Plugin>

=cut
package MKDoc::Auth::Plugin::Login;
use base qw/MKDoc::Core::Plugin/;
use strict;
use warnings;


=head1 API

=head2 $self->uri_hint();

Helps deciding what the URI of this plugin should be.

By default, returns 'signup.html'.

Can be overriden by setting the MKD__AUTH_LOGIN_URI_HINT environment variable
or by subclassing.

=cut
sub uri_hint
{
    return $ENV{MKD__AUTH_LOGIN_URI_HINT} || 'login.html';
}


=head2 $self->location();

Returns the PATH_INFO which will trigger this plugin.

=cut
sub location
{
    my $self = shift;
    return '/.' . $self->uri_hint();
}


=head2 $self->http_get();

If no timestamp is supplied, performs a redirect with a timestamp in the future.

If a timestamp is supplied and is in the future, request browser credentials.

If a timestamp is supplied and is in the past, do not request browser credentials.

=cut
sub http_get
{
    my $self  = shift;

    my $stamp = $self->timestamp() || do {
        my $req   = $self->request();
        my $stamp = time() + 5;
        print $req->redirect ($self->uri() . "?$stamp");
        return 'TERMINATE';
    };
    
    $stamp and time < $stamp and do {
        $::MKD_USER = undef;
        my $rsp = $self->response();
        $rsp->Status ("401 Authorization Required");
        $rsp->WWW_Authenticate ('Basic realm="MKDoc/Auth 0.1"');
    };

    return $self->SUPER::http_get (@_);
}


=head2 $self->timestamp_amount();

Returns the amount of time in the future that should be used to construct the
timestamp, in seconds.

If the time is too short, there is a risk that the user will never have a
chance to log in since the credentials request will never be sent to the
browser.

If the time is too long, there is a risk that the user will have the time to
enter their credentials and click 'OK' before the timestamp expires. This means
that the user will be re-prompted for his credentials, even if they were
correct in the first place.

Defaults to 5. Can be overriden by setting the MKD__AUTH_LOGIN_TIMESTAMP
environment variable or via subclassing. Must be a positive integer which
represent the lapse in seconds.

=cut
sub timestamp_amount
{
    return $ENV{MKD__AUTH_LOGIN_TIMESTAMP} || 5;
}


=head2 $self->timestamp();

Returns the timestamp supplied as a parameter, if any.

=cut
sub timestamp
{
    my $self  = shift;
    my $req   = $self->request()->clone();
    return $req->param ('timestamp') || $req->param ('keywords');
}


=head1 TEMPLATE METHODS

=head2 self/user

Returns the current authenticated user, if any.

=cut
sub user
{
    return $::MKD_USER;
}


1;
