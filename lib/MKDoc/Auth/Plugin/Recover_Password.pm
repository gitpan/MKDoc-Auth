=head1 NAME

MKDoc::Auth::Plugin::Recover_Login - Let users recover their account login.


=head1 SUMMARY

If a user has forgotten their login detail, they can visit /.recover-login.html
and enter their email address.

The plugin will select all the user accounts matching the supplied email
address and send an email containing matching account information.


=head1 INHERITS FROM

L<MKDoc::Core::Plugin>

=cut
package MKDoc::Auth::Plugin::Recover_Password;
use MKDoc::Core::Request;
use MKDoc::Auth::User;
use Crypt::PassGen;
use Petal::Mail;
use strict;
use warnings;
use base qw /MKDoc::Core::Plugin/;


# this is to avoid silly 'used only once' warnings
sub sillyness
{
    $::MKD_Auth_User_CLASS;
}


=head1 API

=head2 $self->location();

Returns the PATH_INFO which will trigger this plugin.

=cut
sub location
{
    my $self = shift;
    return '/.' . $self->uri_hint();
}


=head2 $self->uri_hint();

Helps deciding what the URI of this plugin should be.

By default, returns 'recover-password.html'.

Can be overriden by setting the MKD__AUTH_RECOVER_PASSWORD_URI_HINT environment
variable or by subclassing.

=cut
sub uri_hint
{
    return $ENV{MKD__AUTH_RECOVER_PASSWORD_URI_HINT} || 'recover-password.html';
}


=head2 $self->http_post();

Selects the user account matching the supplied login.

Generates a new temporary password which will be permanent only once used.

Sends an email with the new password.


=cut
sub http_post
{
    my $self  = shift;
    $self->{is_post} = '1';

    my $req   = MKDoc::Core::Request->instance();

    my $login = $req->param ('login') or do {
        new MKDoc::Core::Error 'auth/plugin/recover_password/login_empty';
        return $self->http_get (@_);
    };

    $self->set_login ($login);
    my $user = $self->object() || do {
        new MKDoc::Core::Error 'auth/plugin/recover_password/no_match';
        return $self->http_get (@_);
    };

    $user->crypt_and_set_temp_password ($self->password());

    $self->send_mail();
    return $self->http_get (@_);
}


=head2 $self->send_mail();

Constructs and sends the email.

=cut
sub send_mail
{
    my $self = shift;
    eval
    {
        my $mail = new Petal::Mail (
            language => $self->language(),
            file     => 'auth/emails/recover_password',
        );

        $mail->send (self => $self);
    };

    $@ and do {
        warn $@;
        new MKDoc::Core::Error 'auth/email/cannot_send';
        return 0;
    };

    return 1;
}


=head1 TEMPLATE METHODS

=head2 self/password

Returns the new temporary password.

=cut
sub password
{
    my $self = shift;
    $self->{'.password'} ||= do {
        my ($pass) = Crypt::PassGen::passgen();
        $pass;
    };

    return $self->{'.password'};
}


sub set_login
{
    my $self = shift;
    $self->{'.login'} = shift;
}


=head2 self/login

Returns the user login.

=cut
sub login
{
    my $self = shift;
    return $self->{'.login'};
}


=head2 self/object

Returns the user matching self/login

=cut
sub object
{
    my $self  = shift;
    my $login = $self->login() || return;
    my $class = $::MKD_Auth_User_CLASS || 'MKDoc::Auth::User'; 
    return $class->load_from_login ($login);
}

 
1;
