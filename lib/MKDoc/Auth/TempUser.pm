=head1 NAME

MKDoc::Auth::TempUser - Simple temp user class for MKDoc::Auth


=head1 OVERVIEW

L<MKDoc::Auth> provides a simple and efficient user account signup facility. It
works as follows:

=over 4

=item A user goes to a signup page, typically /.signup.html.

=item A user enter his email address and name and sumbits the form.

=item An email is sent to the user with his login, password, and a confirmation link.

=item The user clicks on the confirmation link.

=item The user is now confirmed and is able to login.

=back

This process ensures that the users email addresses are all valid.
Additionally, it guarantees that the user has not been maliciously subscribed
by someone else.

Before the user has completed confirmation step, it would be unwise to store
that user directly in the database since it could be full of bogus users who
never actually clicked on the confirmation link.

So instead, L<MKDoc::Auth::TempUser> objects are created. They are stored on
disk for a limited amount of time using L<Cache::FileCache> via the
L<MKDoc::Core::FileCache> wrapper.

The users are stored along with a confirmation number which has to be supplied
in order to activate the user account. If the confirmation number is correct,
the temporary user can be 'upgraded' to a normal user since their email address
has been confirmed.

This module is used by L<MKDoc::Auth::Plugin::Signup> and
L<MKDoc::Auth::Plugin::Confirm>.


=head1 INHERITANCE

L<MKDoc::Auth::User>

=cut
package MKDoc::Auth::TempUser;
use MKDoc::Core::Error;
use Mail::CheckUser;
use MKDoc::Core::FileCache;
use Crypt::PassGen;
use Data::Dumper;
use MKDoc::Auth;
use warnings;
use strict;

our @ISA = ();


=head1 API

=head2 $self->id();

Returns the object identifier.

In the special case of L<MKDoc::Auth::TempUser> objects, id() is an alias for login().

=cut
sub id { return shift->login() }


=head2 $self->load ($login);

Loads an L<MKDoc::Auth> object with login $login.

=cut
sub load { return shift->load_from_login (@_) }


sub _validate_id { return 1 }


=head2 $self->new();

Same as L<MKDoc::Auth::User>::new(), except that it adds a randomly generated
'confirm_nb' attribute.

This attribute is used as a confirmation ticket when a user confirms / activates
his accounts.

=cut
sub new
{
    my $class = shift;

    local @ISA = ();
    push  @ISA, $::MKD_Auth_User_CLASS || 'MKDoc::Auth::User';

    return $class->SUPER::new ( @_, confirm_nb => Crypt::PassGen::passgen() );
}


=head2 $self->confirm ($confirmation_nb);

Checks that $confirmation_nb matches the confirmation number of the object.

If it does, removes $self from the cache and turns it into a permanent
L<MKDoc::Auth> object, and saves it.

=cut
sub confirm
{
    my $self = shift;
    my $nb   = shift;
    $self->confirm_nb() eq $nb and do {
        my $class = $::MKD_Auth_User_CLASS || 'MKDoc::Auth::User';
        $class->new (
            login     => $self->login(),
            password  => $self->password(),
            email     => $self->email(),
            full_name => $self->full_name()
        ) || return 0;

        $self->delete();
        return 1;
    };
    
    return 0;
}


=head2 $self->confirm_nb();

Returns this object's confirmation number.

=cut
sub confirm_nb
{
    my $self = shift;
    return $self->{confirm_nb};
}


=head2 $self->set_confirm_nb ($confirmation_nb);

Sets this object's confirmation number to $confirmation_nb.

=cut
sub set_confirm_nb
{
    my $self = shift;
    $self->{confirm_nb} = shift;
}


=head2 $class->list();

Lists all objects from the cache _ONLY_, i.e. returns only
L<MKDoc::Auth::TempUser> objects.

=cut
sub list
{
    my $self  = shift;
    my $cache = $self->_cache_object();
    my @res   = map { $self->load_from_login ($_) } $cache->keys();
    @res = sort { $a->full_name() cmp $b->full_name() } @res;
    return wantarray ? @res : \@res;
}


=head2 $class->load_from_login ($login);

Returns any object which matches $login, in this order:

First attempts to load a L<MKDoc::Auth::User> object matching $login, even if
this object is marked as deleted.

Attempts to load a L<MKDoc::Auth::TempUser> object from the cache.

Returns undef

=cut
sub load_from_login
{
    my $class  = shift || return;
    my $login  = shift || return;
    my $cache  = $class->_cache_object();

    local @ISA = ();
    push  @ISA, $::MKD_Auth_User_CLASS || 'MKDoc::Auth::User';

    return $class->SUPER::load_from_login_even_if_deleted ($login) || do {
        my $VAR1;
        my $data = $cache->get ($login) || return;
        eval $data;
        $VAR1;
    };
}


sub _insert
{
    my $self   = shift;
    my $data  = Dumper ($self);
    my $cache = $self->_cache_object();
    $cache->set ($self->login(), $data, $self->_expiration_time());
    return $self;
}


sub _modify { shift->_insert (@_) }


=head2 $self->delete();

Removes this temporary object from the cache.

=cut
sub delete
{
    my $self  = shift;
    my $login = $self->login();
    my $cache = $self->_cache_object();
    $self->{'.new'} = 1;
    $cache->remove ($login);
}


=head2 $class->_expiration_time();

Defines how long the temporary object will live in the cache for.

By default, returns '1 month', i.e. if a user does not confirm his account
within one month then he'll have to sign-up again.

This value can be overriden with the environment variable
MKD__AUTH_TEMPUSER_EXPIRES.

The value can be anything that L<Cache::Cache> will understand.

=cut
sub _expiration_time
{
    return $ENV{MKD__AUTH_TEMPUSER_EXPIRES} || '1 month';
}


sub _cache_object
{
    return MKDoc::Core::FileCache->instance ('MKDoc::Auth::TempUser');
}


1;


__END__
