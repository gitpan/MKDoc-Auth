=head1 NAME

MKDoc::Auth::Plugin::Signup - Let users open new user accounts.


=head1 SUMMARY

This module lets users open new user accounts.

Rather than creating L<MKDoc::Auth::User> objects, this module creates
L<MKDoc::Auth::TempUser> objects and sends an email containing a confirmation
link.

L<MKDoc::Auth::TempUser> objects live for a limited amount of time in a disk
cache rather than in the database.

When a user visits the confirmation page, the L<MKDoc::Auth::TempUser> is
deleted and turned into a regular L<MKDoc::Auth::User> object which lives in
the database.

This process has a triple advantage:

=over 4

=item Account subscription is truly opt-in.

=item User email address is guaranteed at the time of subscription.

=item Your user table is not filled up with bogus user accounts.

=back


=head1 INHERITS FROM

L<MKDoc::Core::Plugin>

=cut
package MKDoc::Auth::Plugin::Signup;
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

By default, returns 'signup.html'.

Can be overriden by setting the MKD__AUTH_SIGNUP_URI_HINT environment variable
or by subclassing.

=cut
sub uri_hint
{
    return $ENV{MKD__AUTH_SIGNUP_URI_HINT} || 'signup.html';
}


=head2 $self->http_post();

When a form is submitted, it means that a user has filled in the subscription
form and pressed OK.

This method processes the POST operation.

It attempts to create a new L<MKDoc::Auth::TempUser> based on the information
passed in the signup form.

=cut
sub http_post
{
    my $self = shift;
    my $req  = MKDoc::Core::Request->instance();

    my $user = MKDoc::Auth::TempUser->new (
	login      => $self->login(),
        email      => $req->param ('email'),
        full_name  => $req->param ('full_name'),
        password_1 => $self->password(),
        password_2 => $self->password(),
    ) || return $self->http_get();


    $self->set_object ($user);
    $self->send_mail();
    return $self->http_get (@_);
}


=head2 $self->send_mail();

This method is used when a L<MKDoc::Auth::TempUser> was successfully created.

It sends an email containing a confirmation link (see
L<MKDoc::Auth::Plugin::Confirm>) as well as the user details.

=cut
sub send_mail
{
    my $self = shift;
    eval
    {
        my $mail = new Petal::Mail (
            language => $self->language(),
            file     => 'auth/emails/signup',
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


sub set_object
{
    my $self = shift;
    $self->{'.object'} = shift;
}


=head1 TEMPLATE METHODS

=head2 self/object

Returns the newly created L<MKDoc::Auth::TempUser> object, if any. If
self/object exists, then you can invoke L<MKDoc::Auth::TempUser> methods.

  <ul petal:condition="true: self/object">
    <li>Login: <span petal:replace="self/object/login">fred</span></li>
    <li>Full Name: <span petal:replace="self/object/full_name">Fred FlintStone</span></li>
    <!--? etc. ?-->
  </ul>

=cut
sub object
{
    my $self = shift;
    return $self->{'.object'};
}


=head2 self/password

Returns the password which has been generated for the new user.

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


=head2 self/login

Returns the login which has been genereated for the new user.

=cut
sub login
{
    my $self  = shift;
    $self->{'.login'} ||= $self->_find_free_login(); 
    return $self->{'.login'};
}


sub _find_free_login
{
    my $self  = shift;
    my $req   = $self->request();

    my $login = $req->param ('email') || '';
    $login    =~ s/\@.+//;
    $login    = lc ($login);
    $login    =~ s/[^a-z]//g;
    $login  ||= 'login';

    length ($login) > 12 && do { $login = substr ($login, 0, 12) };
  
    MKDoc::Auth::TempUser->load_from_login ($login) || return $login;
    my $count = 2;
    my $new_login = $login . $count;
    while (MKDoc::Auth::TempUser->load_from_login ($new_login))
    {
        $count++;
        $new_login = $login . $count;
    }

    $new_login;
}


1;
