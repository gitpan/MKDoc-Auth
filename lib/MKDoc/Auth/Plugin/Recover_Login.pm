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
package MKDoc::Auth::Plugin::Recover_Login;
use MKDoc::Core::Request;
use MKDoc::Auth::TempUser;
use Crypt::PassGen;
use Petal::Mail;
use strict;
use warnings;
use base qw /MKDoc::Core::Plugin/;


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

By default, returns 'recover-login.html'.

Can be overriden by setting the MKD__AUTH_RECOVER_LOGIN_URI_HINT environment variable
or by subclassing.

=cut
sub uri_hint
{
    return $ENV{MKD__AUTH_RECOVER_LOGIN_URI_HINT} || 'recover-login.html';
}


=head2 $self->http_post();

Selects all the user account matching the supplied email address.

Constructs and sends an email with those account details.

=cut
sub http_post
{
    my $self  = shift;
    $self->{is_post} = '1';

    my $req = MKDoc::Core::Request->instance();

    my $email = $req->param ('email') or do {
        new MKDoc::Core::Error 'auth/plugin/recover_login/email_empty';
        return $self->http_get (@_);
    };
    
    $self->set_email ($email);
    my @users = $self->matching_users();
    scalar @users or do {
        new MKDoc::Core::Error 'auth/plugin/recover_login/no_match';
        return $self->http_get (@_);
    };

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
            file     => 'auth/emails/recover_login',
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


sub set_email
{
    my $self = shift;
    $self->{'.email'} = shift;
}



=head1 TEMPLATE METHODS


=head2 self/email

The user supplied email.

=cut
sub email
{
    my $self = shift;
    return $self->{'.email'};
}


=head2 self/matching_users

A list of user accounts which match the user supplied emails.

=cut
sub matching_users
{
    my $self  = shift;
    my $email = $self->email() || return;
    my $class = $::MKD_Auth_User_CLASS || 'MKDoc::Auth::User';
    my @res   = $class->find_from_email ($email);
    return wantarray ? @res : \@res;
}

 
1;
