=head1 NAME

MKDoc::Auth::Handler::Authenticate - MKDoc::Auth apache authentication handler


=head1 OVERVIEW

This handler password-protects / authenticates a portion of your site
MKDoc::Auth user database. It is useful if for example you wish some portion of
your site to be accessible to "members only". 

  <Location /private/>
    PerlAuthenHandler MKDoc::Handler::Authenticate
    AuthName "MKDoc/Auth"
    AuthType Basic
    require valid-user
  </Location>

This module is here for completeness, it is not actually set up by
L<MKDoc::Setup::Auth>. However it is here just in case you might need it. 

=cut
package MKDoc::Auth::Handler::Authenticate;
use MKDoc::Auth::User;
use Apache::Constants qw/:common/;
use strict;
use warnings;


=head1 API

=head2 get_login();

If the browser has sent credentials, returns the login which has been sent.

Returns undef otherwise.

=cut
sub get_login
{
    my $r = Apache->request();
    my %args = $r->args();
    return $r->connection->user() || ''; 
}


=head2 get_password();

If the browser has sent the credentials, returns the password which has been sent.

Returns undef otherwise.

=cut
sub get_password
{
    my $r = Apache->request();
    my ($res, $sent_pw) = $r->get_basic_auth_pw;
    my %args = $r->args();
    return $sent_pw || ''; 
}


=head2 handler()

If the browser has sent the credentials and the credentials match an existing
L<MKDoc::Auth::User>, sets $::MKD_USER to this object and returns OK.

Otherwise, return AUTH_REQUIRED.

=cut
sub handler
{
    my $r = shift;

    $::MKD_USER = undef;

    # checks that the user has sent a login / password pair
    my ($res, $sent_pw) = $r->get_basic_auth_pw;
    $res == OK or return $res;
    
    my $pass  = get_password(); 
    my $login = get_login(); 

    unless ($login and $pass)
    {
        $r->note_basic_auth_failure;
        return AUTH_REQUIRED;
    }
   
    # fetches the user
    my $user = MKDoc::Auth::User->load_from_login ($login) || do {
        $r->note_basic_auth_failure;
        return AUTH_REQUIRED;
    };
    
    # compares the real password with the provided password
    $user->check_password ($pass) || do {
        $r->note_basic_auth_failure;
        return AUTH_REQUIRED;
    };

    $::MKD_USER = $user;
    return OK;
}


1;


__END__
