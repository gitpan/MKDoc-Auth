=head1 NAME

MKDoc::Auth::Plugin::Confirm - Let users confirm their accounts.


=head1 SUMMARY

Once a user has been through L<MKDoc::Auth::Plugin::Signup>, they are sent an
email which contains an activation / confirmation link.  The link should point
to this plugin.

The link has the following form:

    http://<SERVER_NAME>/~<login>/.confirm.html?<confirm_nb>

L<MKDoc::Auth::Plugin::Confirm> loads the L<MKDoc::Auth::TempUser> which
matches <login> and invokes this object confirm() method with the <confirm_nb>
which is contained in the confirmation link.

If the L<MKDoc::Auth::TempUser> confirm_nb matches the user supplied
confirm_nb, the L<MKDoc::Auth::TempUser> becomes a regular
L<MKDoc::Auth::User>, which activates / confirms the account.


=head1 INHERITS FROM

L<MKDoc::Core::Plugin>

=cut
package MKDoc::Auth::Plugin::Confirm;
use MKDoc::Auth::TempUser;
use MKDoc::Auth::User;
use strict;
use warnings;
use base qw /MKDoc::Core::Plugin/;


=head1 API

=head2 $self->activate();

Returns 1 only if the PATH_INFO looks like /~<login>/.confirm.html, and <login>
is an existing user (wether this user is temporary or not).

=cut
sub activate
{
    my $self  = shift;
    return $self->object(); 
}


=head2 $self->uri_hint();

Helps deciding what the URI of this plugin should be.

By default, returns 'confirm.html'.

Can be overriden by setting the MKD__AUTH_CONFIRM_URI_HINT environment variable
or by subclassing.

=cut
sub uri_hint
{
    return $ENV{MKD__AUTH_CONFIRM_URI_HINT} || 'confirm.html';
}


=head2 $self->http_get();

Processes this request. Attempts to confirm the current user with the supplied
confirmation number, if any.

=cut
sub http_get
{
    my $self = shift;
    $self->is_inactive() and do {
        my $req  = $self->request();
        my $id   = $req->param ('keywords') || '';
        my $obj  = $self->object() || return;

        $obj->confirm ($id) or do {
            new MKDoc::Core::Error 'auth/confirm/mismatch';
        };
    };
 
    return $self->SUPER::http_get (@_); 
}



=head1 TEMPLATE METHODS


=head2 self/uri [ --object some/object ]

Returns the URI of this plugin.

Since this plugin deals with multiple users, it can have multiple URIs.

If this plugin has been invoked by the current request, it will extract its
associated user from the current request.

However if this plugin object has been instanciated by another plugin, then the
associated object has to be supplied to this method as follows:

  my $user = get_some_user();
  my $confirm_p = MKDoc::Auth::Plugin::Confirm->new();
  print $confirm_p->uri (object => $user);

Of course this can be done from the template, typically to display the
confirmation link URI.

  <pre petal:content="confirm_plugin/uri --object self/object">ACTIVATE_URI</pre>

=cut
sub uri
{
    my $self   = shift;
    my $args   = { @_ };

    my $object = $self->object() || delete $args->{object} || do {
        warn $self . '::uri() - could not find matching login';
        return;
    };

    my $login  = $object->login();
    
    local *location;
    *location = sub { "/~$login/." . $self->uri_hint() };
    
    return $self->SUPER::uri() . '?' . $object->confirm_nb();
}


=head2 self/object

Returns the data object (a L<MKDoc::Auth::User> or L<MKDoc::Auth::TempUser>
object) associated with this plugin.

=cut
sub object
{
    my $self  = shift || return;
    my $req   = $self->request();
    my $path  = $req->path_info();
    my $hint  = quotemeta ($self->uri_hint());

    my ($login) = $path =~ /^\/~(.*)\/\.$hint$/;
    $login || return;

    my $obj = MKDoc::Auth::TempUser->load_from_login ($login) || return;
    return $obj;
}


=head2 self/is_active

Returns TRUE if this account is already active, false otherwise.

=cut
sub is_active
{
    my $self = shift;
    return not $self->is_inactive (@_);
}


sub is_inactive
{
    my $self   = shift;
    my $object = $self->object();
    return $object->isa ('MKDoc::Auth::TempUser');
}



1;
