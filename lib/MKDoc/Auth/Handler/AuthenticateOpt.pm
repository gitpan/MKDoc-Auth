=head1 NAME

MKDoc::Auth::Handler::AuthenticateOpt - MKDoc::Auth apache optional authentication handler


=head1 OVERVIEW

This handler is used as an optional authentication mechanism.

It does *not* password protect a portion of your site. Instead, _if_ the client
browser sends user credentials, and if those credentials match an existing
L<MKDoc::Auth::User>, then this user object will be set in the variable
$::MKD_USER. 

The L<MKDoc::Auth::Plugin::Login> module does some trickery to get the browser
to send the credentials.

In your httpd.conf this module is used as follows:

  <Location />
    PerlFixupHandler MKDoc::Auth::Handler::AuthenticateOpt
  </Location>

However when you install L<MKDoc::Auth> onto a given site, this apache
configuration should be deployed for you. All you need to do after you're done
is restart apache.

=cut
package MKDoc::Auth::Handler::AuthenticateOpt;
use MKDoc::Auth::User;
use Apache::Constants qw/:common/;
use MIME::Base64;
use strict;
use warnings;


=head1 API

=head2 get_login();

If the browser sent authentication credentials, returns the login part of the
credentials.

Returns undef otherwise.

=cut
sub get_login
{
    my $r = Apache->request();
    my $authorization = $r->header_in ('Authorization') || return;
    $authorization =~ s/^Basic (.*)/$1/;
    $authorization = decode_base64 ($authorization);
    my ($user, $sent_pwd) = split (':', $authorization);
    return $user;
}


=head2 get_password();

If the browser sent authentication credentials, returns the password part of
the credentials.

Returns undef otherwise.

=cut
sub get_password
{
    my $r = Apache->request();
    my %headers = $r->headers_in();
    my $authorization = $r->header_in ('Authorization') || return;
    $authorization =~ s/^Basic (.*)/$1/;
    $authorization = decode_base64 ($authorization);
    my ($user, $sent_pwd) = split (':', $authorization);
    return $sent_pwd;
}


=head2 handler();

If the browser sent authentication credentials, and those credentials matched
an existing L<MKDoc::Auth::User>, sets the user in $::MKD_USER.

This modules always returns OK, even if the credentials were not sent or were
incorrect. However the $::MKD_USER is set only whenever the credentials are
sent and correct.
 
=cut
sub handler
{
    my $r = shift;
    $::MKD_USER = undef;
    $::AUTH_FAILED = undef;

    my $pass  = get_password() || return OK;
    my $login = get_login()    || return OK;

    my $user  = MKDoc::Auth::User->load_from_login ($login) || return OK;
    $user->check_password ($pass)                           || return OK;

    $::MKD_USER = $user;
    return OK; 
}


1;


__END__
