=head1 NAME

MKDoc::Auth::Plugin::Edit - Let users edit their own accounts. 


=head1 SUMMARY

This module lets users edit their account details, i.e. first name, email
address and password.


=head1 INHERITS FROM

L<MKDoc::Core::Plugin>

=cut
package MKDoc::Auth::Plugin::Edit;
use MKDoc::Auth::User;
use strict;
use warnings;
use base qw /MKDoc::Core::Plugin/;


=head2 $self->activate();

If the URI looks like /~<login>/.edit.html, and <login> is the same as the
current user in $::MKD_USER, returns TRUE.

Otherwise, returns FALSE.

=cut
sub activate
{
    my $self   = shift;
    my $object = $self->object() || return;

    $::MKD_USER || return;
    return $::MKD_USER->login() eq $object->login();
}


=head2 $self->uri_hint();

Helps deciding what the URI of this plugin should be.

By default, returns 'edit.html'.

Can be overriden by setting the MKD__AUTH_EDIT_URI_HINT environment variable or
by subclassing.

=cut
sub uri_hint
{
    return $ENV{MKD__AUTH_EDIT_URI_HINT} || 'edit.html';
}


=head2 $self->http_get();

Displays a web form which lets the user change their user details.

=cut
sub http_get
{
    my $self = shift;
    my $req  = $self->request();
    my $obj  = $self->object();
    $req->param ( 'full_name' => $req->param ('full_name') || $obj->full_name() );
    $req->param ( 'email'     => $req->param ('email')     || $obj->email()     );
    return $self->SUPER::http_get (@_); 
}


=head2 $self->http_post();

Processes the web form which was displayed by $self->http_get().

If there were errors processing the form, re-display $self->http_get().

If the modification was successful, redirects to $self->return_uri().

=cut
sub http_post
{
    my $self = shift;
    my $req  = $self->request();
    my $obj  = $self->object();
    $obj->set_full_name ($req->param ('full_name'));
    $obj->set_email ($req->param ('email'));
    $obj->set_password_1 ($req->param ('password_1'));
    $obj->set_password_2 ($req->param ('password_2'));
    $obj->save() || return $self->http_get (@_);

    print $req->redirect ($self->return_uri());
    return 'TERMINATE';
}


=head1 TEMPLATE METHODS


=head2 $self->return_uri();

The return URI of this module, i.e. where should we go once we're done.

=cut
sub return_uri
{
    require "MKDoc/Auth/Plugin/Login.pm";
    my $stamp = time - 1;
    return MKDoc::Auth::Plugin::Login->new()->uri() . "?$stamp";
}


=head2 $self->uri();

Returns the URI of this plugin.

Since this plugin deals with multiple users, it can have multiple URIs.

If this plugin has been invoked by the current request, it will extract its
associated user from the current request.

However if this plugin object has been instanciated by another plugin, then the
associated object has to be supplied to this method as follows:

  my $user = get_some_user();
  my $edit_p = MKDoc::Auth::Plugin::Edit->new();
  print $edit_p->uri (object => $user);

Of course this can be done from the template, typically to construct a link for
the user to edit his account if he so wishes.

  <!--? assuming that the current user is returned by self/object ?-->
  <a href="#"
     petal:define="edit_p plugin: MKDoc::Auth::Plugin::Edit"
     petal:attributes="href edit_p/uri --object self/object">Edit Account Info</a>

=cut
sub uri
{
    my $self  = shift;
    my $args  = { @_ };

    # attempts to get the login from the arguments
    my $login = delete $args->{object};
    ref $login and do { $login = $login->login() };

    # if unsuccessful, try to get the login from
    # the current location
    $login ||= $self->object();
    ref $login and $login = $login->login();

    # if unsuccessful, try to get the login from
    # the current user
    $login ||= $::MKD_USER->login() if ($::MKD_USER);
    
    # if unsuccessful, return nothing
    $login ||= do {
        warn $self . '::login() - could not find matching login';
        return;
    };
    
    # lie about what the location() is so that we get the right URI
    my $req = $self->request()->clone();
    
    local *location;
    *location = sub { "/~$login/." . $self->uri_hint() };
    
    return $self->SUPER::uri ( %{$args} );
}


=head2 self/object

Return the current L<MKDoc::Auth::User> object.

=cut
sub object
{
    my $self  = shift || return;
    my $req   = $self->request();
    my $path  = $req->path_info();
    my $hint  = quotemeta ($self->uri_hint());

    my ($login) = $path =~ /^\/~(.*)\/\.$hint$/;
    $login || return;

    return MKDoc::Auth::User->load_from_login ($login);
}


1;
