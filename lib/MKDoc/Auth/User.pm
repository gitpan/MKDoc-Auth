=head1 NAME

MKDoc::Auth::User - Simple user class for MKDoc::Auth

=cut
package MKDoc::Auth::User;
use MKDoc::Core::Error;
use Mail::CheckUser;
use MKDoc::SQL;
use MKDoc::Core::FileCache;
use warnings;
use strict;

$Mail::CheckUser::Timeout = 5;
$Mail::CheckUser::Treat_Timeout_As_Fail = undef;
$Mail::CheckUser::Treat_Full_As_Fail = undef;


=head1 API

=head2 $class->sql_table();

Returns the L<MKDoc::SQL::Table> object associated with this class. This object
represents the table in which L<MKDoc::Auth::User> objects are stored.

=cut
sub sql_table
{
    my $class = shift;
    my $name  = $class->sql_name(); 
    return MKDoc::SQL::Table->table ($name);
}


=head2 $class->sql_name();

Returns the name of the SQL table in which L<MKDoc::Auth::User> objects are
stored.

=cut
sub sql_name { return 'MKDoc_Auth_User' }


=head2 $class->sql_schema();

Instanciates and returns the L<MKDoc::SQL::Table> object in which L<MKDoc::Auth::User>
objects are stored.

=cut
sub sql_schema
{
    my $class = shift;
    new MKDoc::SQL::Table (
        bless_into => 'MKDoc::Auth::User',
        name       => $class->sql_name(), 
        pk         => [ qw /ID/ ],
        ai         => 1,
        unique     => { login_unique => [ qw /Login/ ] },
        cols       => [
            { name => 'ID',            type => new MKDoc::SQL::Type::Int  ( not_null => 1 )              },
            { name => 'Login',         type => new MKDoc::SQL::Type::Char ( size => 50, not_null => 1 )  },
            { name => 'Password',      type => new MKDoc::SQL::Type::Char ( size => 50, not_null => 1 )  },
            { name => 'Email',         type => new MKDoc::SQL::Type::Char ( size => 100, not_null => 1 ) },
            { name => 'Full_Name',     type => new MKDoc::SQL::Type::Char ( size => 100 )                },
            { name => 'Is_Deleted',    type => new MKDoc::SQL::Type::Int  ( not_null => 1 )              },
        ],
    );
}


=head2 $class->max_login_length();

The maximum length of the login field.

=head2 $class->min_login_length();

The minimum length of the login field.

=head2 $class->max_password_length();

The maximum length of the password.

=head2 $class->min_password_length();

The minimum length of the password.

=cut
sub max_login_length    { 255 }
sub min_login_length    { 2   }
sub max_password_length { 50  }
sub min_password_length { 5   }


=head2 $self->validate();

Validates this object. For each error encountered, instanciates L<MKDoc::Core::Error>
objects. If you are using a L<MKDoc::Core::Plugin> object.

Possible error flags:

=over 4

=item auth/user/id/undefined - The object is not new, but it has no ID field

=item auth/user/id/no_match - The object is not new, but its ID field was not in the database

=item auth/user/login/empty - This object Login attribute is empty

=item auth/user/login/too_short - This object Login attribute is too short

=item auth/user/login/loo_long - This object Login attribute is too long

=item auth/user/login/exists - This object is new, but the login already exists in the database

=item auth/user/login/changed - This object is not new. Its login cannot be changed

=item auth/user/password/empty - This object 'Password_1' attribute is empty

=item auth/user/password/too_short - This object 'Password_1' attribute is too short

=item auth/user/password/too_long - This object 'Password_1' attribute is loo long

=item auth/user/password/mismatch - This object 'Password_1' and 'Password_2' attributes do not match

=item auth/user/password/empty - No password was set for this object

=item auth/user/email/empty - This object 'Email' attribute is empty

=item auth/user/email/invalid - This object 'Email' attribute is not valid

=item auth/user/full_name/empty - This object 'Full_Name' attribute is undefined or empty

=item auth/user/full_name/too_short - This object 'Full_Name' attribute is too short

=item auth/user/full_name/too_long - This object 'Full_Name' attribute is too long

=back

=cut
sub validate
{
    my $self = shift;
    return $self->_validate_id()        &
           $self->_validate_login()     &
           $self->_validate_password()  &
           $self->_validate_email()     &
           $self->_validate_full_name();
}


sub _validate_id
{
    my $self = shift;
    
    # if the object is new, there must be no ID
    $self->{'.new'} and do {
        delete $self->{ID};
        return 1;
    };
    
    # if the object is not new, there must be an ID
    # and this ID must exist in the database.
    my $id = $self->id() || do {
        new MKDoc::Core::Error 'auth/user/id/undefined';
        return 0;
    };

    $self->load ($id) || do {
        new MKDoc::Core::Error 'auth/user/id/no_match';
        return 0;
    };

    return 1;
}


sub _validate_login
{
    my $self = shift;
    my $login = $self->login() || do {
        new MKDoc::Core::Error 'auth/user/login/empty';
        return 0;
    };

    if ( $self->{'.new'} )
    {
        length ($login) < $self->min_login_length() and do {
            new MKDoc::Core::Error 'auth/user/login/too_short';
            return 0;
        };

        length ($login) > $self->max_login_length() and do {
            new MKDoc::Core::Error 'auth/user/login/too_long';
            return 0;
        };

        $self->load_from_login ($login) and do {
            new MKDoc::Core::Error 'auth/user/login/exists';
            return 0;
        };
    }
    else
    {
        my $self_copy = $self->load_from_login ($login);

        $self_copy->id() == $self->id() or do {
            new MKDoc::Core::Error 'auth/user/login/changed';
            return 0;
        };
    }

    return 1;
}


sub _validate_password
{
    my $self = shift;

    my $password_1 = $self->password_1() || '';
    my $password_2 = $self->password_2() || '';

    $password_1 || $password_2 and do {

        $password_1 || do {
            die "Why?";
            new MKDoc::Core::Error 'auth/user/password/empty';
            return 0;
        };

        length ($password_1) < $self->min_password_length() and do {
            new MKDoc::Core::Error 'auth/user/password/too_short';
            return 0;
        };

        length ($password_1) > $self->max_password_length() and do {
            new MKDoc::Core::Error 'auth/user/password/too_long';
            return 0;
        };
        
        $password_1 eq $password_2 or do {
            new MKDoc::Core::Error 'auth/user/password/mismatch';
            return 0;
        };

        delete $self->{'Password_1'};
        delete $self->{'Password_2'};
        my $password = crypt ($password_1, $self->login());
        $self->set_password ($password);
    };

    $self->password() || do {
        new MKDoc::Core::Error 'auth/user/password/empty';
        return 0;
    };

    return 1;
}


sub _validate_email
{
    my $self  = shift;
    my $email = $self->email() || do {
        new MKDoc::Core::Error 'auth/user/email/empty';
        return 0;
    };
    
    Mail::CheckUser::check_email ($email) || do {
        new MKDoc::Core::Error 'auth/user/email/invalid';
        return 0;
    };

    return 1;
}


sub _validate_full_name
{
    my $self = shift;
    $self->full_name() || do {
        new MKDoc::Core::Error 'auth/user/full_name/empty';
        return 0;
    };

    return 1;
}


=head2 $class->new (%args);

Creates a new L<MKDoc::Auth::User> object. %args must be:

  email      => $email_address,
  full_name  => $full_name,
  password_1 => $user_password,
  password_2 => $user_password,

The 'email' argument will also be used as the login of the user.

=cut
sub new
{
    my $class = shift;
    my %args  = @_;

    my $self  = bless {}, $class;
    foreach my $key (%args)
    {
        my $met = "set_$key";
        $self->can ($met) and $self->$met ( $args{$key} );
    }

    $self->{Is_Deleted} = 0;
    $self->{'.new'} = 1;
    return $self->save;
}


=head2 $class->list();

Returns all L<MKDoc::Auth::User> objects which have been saved.

=cut
sub list
{
    my $class  = shift;
    my $user_t = $class->sql_table();
    my $query  = $user_t->search (Is_Deleted => 0);
    my @res    = ();
    while (my $user = $query->next()) { push @res, $user }
    @res = sort { $a->full_name() cmp $b->full_name() } @res;
    return wantarray ? @res : \@res;
}


=head2 $class->load ($id);

Returns the L<MKDoc::Auth::User> object from its object id.

=cut
sub load
{
    my $class  = shift || return;
    my $id     = shift || return;
    my $user_t = $class->sql_table();
    return $user_t->get ( ID => $id, Is_Deleted => 0);
}


=head2 $class->load_from_login ($login);

Returns the L<MKDoc::Auth::User> object with login $login.

=cut
sub load_from_login
{
    my $class  = shift || return;
    my $login  = shift || return;
    my $user_t = $class->sql_table();
    return $user_t->get ( Login => $login, Is_Deleted => 0 );
}


sub load_from_login_even_if_deleted
{
    my $class  = shift || return;
    my $login  = shift || return;
    my $user_t = $class->sql_table();
    return $user_t->get ( Login => $login );
}


=head2 $class->find_from_email ($email);

Finds all the users whose email address is matching $email.

=cut
sub find_from_email
{
    my $class  = shift || return;
    my $email  = shift || return;
    my $user_t = $class->sql_table();
    my @res    = $user_t->search ( Email => $email, Is_Deleted => 0 )->fetch_all();
    return @res;
}


=head2 $self->save();

Saves the object into the database. If the object is new, inserts it.
Otherwise updates it.

=cut
sub save
{
    my $self = shift;
    $self->validate() || return;
    $self->{'.new'} ? $self->_insert() : $self->_modify();
    
    return $self;
}


sub _insert
{
    my $self   = shift;
    my $user_t = $self->sql_table();
    delete $self->{'.new'};
    $user_t->insert ($self);
}


sub _modify
{
    my $self   = shift;
    my $user_t = $self->sql_table();
    delete $self->{'.new'};
    $user_t->modify ($self);
}


=head2 $self->delete();

Deletes the object from the database.

=cut
sub delete
{
    my $self   = shift;
    my $user_t = $self->sql_table();
    $self->{Is_Deleted} = 1;
    $self->save();
}


=head2 $self->id();

Returns the identifier of this object.

=cut
sub id
{
    my $self = shift;
    return $self->{ID};
}


=head2 $self->login();

Returns the Login attribute of this object.

=cut
sub login
{
    my $self = shift;
    return $self->{Login};
}


=head2 $self->set_login ($login);

Sets the Login attribute for this object.

=cut
sub set_login
{
    my $self = shift;
    $self->{Login} = shift;
}


=head2 $self->password_1();

Returns the proposed new password of this object.

=cut
sub password_1
{
    my $self = shift;
    return $self->{Password_1};
}


=head2 $self->set_password_1 ($new_password);

Sets the proposed new password for this object.

=cut
sub set_password_1
{
    my $self = shift;
    $self->{Password_1} = shift;
}


=head2 $self->password_2();

Returns the proposed new password verification of this object.

=cut
sub password_2
{
    my $self = shift;
    return $self->{Password_2};
}


=head2 $self->set_password_2 ($new_password_verify);

Sets the proposed new password verification for this object.

=cut
sub set_password_2
{
    my $self = shift;
    $self->{Password_2} = shift;
}


=head2 $self->password();

Returns the encrypted password of this object.

=cut
sub password
{
    my $self = shift;
    return $self->{Password};
}


=head2 $self->set_password();

Sets the encrypted password of this object.

=cut
sub set_password
{
    my $self = shift;
    $self->{Password} = shift;
}


=head2 $self->check_password ($pass);

Checks wether the encrypted $pass matches $self->password().

=cut
sub check_password
{
    my $self  = shift || return;
    my $pass  = shift || return;
    my $crypt = crypt ($pass, $self->login());
    return 1 if ($self->password() eq $crypt);
    
    # we give another chance with the temp_password(),
    # if there is any.
    $self->temp_password() and $self->check_temp_password ($pass) and do {
        $self->set_password ($self->temp_password());
        $self->delete_temp_password();
        $self->save();
        return 1;
    };

    return 0;
}


=head2 $self->full_name();

Returns the full name of this object.

=cut
sub full_name
{
    my $self = shift;
    return $self->{Full_Name};
}


=head2 $self->set_full_name ($full_name);

Sets the full name of this object.

=cut
sub set_full_name
{
    my $self = shift;
    $self->{Full_Name} = shift;
}


=head2 $self->email();

Returns the email of this object.

=cut
sub email
{
    my $self = shift;
    return $self->{Email};
}


=head2 $self->set_email ($email);

Sets the email of this object.

=cut
sub set_email
{
    my $self = shift;
    $self->{Email} = shift;
}


=head2 $self->crypt_and_set_temp_password ($clear_password);

Encryps $clear_password and sets it as a temporary password.

=cut
sub crypt_and_set_temp_password
{
    my $self  = shift || return;
    my $pass  = shift || return;
    my $crypt = crypt ($pass, $self->login());
    $self->set_temp_password ($crypt);
}


=head2 $self->set_temp_password ($crypted_pass);

Sets the encrypted password of this object.

=cut
sub set_temp_password
{
    my $self  = shift;
    my $login = $self->login();
    my $cache = $self->_temp_password_cache_object();
    $cache->set ($login, shift);
}


=head2 $self->temp_password();

Gets the encrypted password of this object.

=cut
sub temp_password
{
    my $self  = shift;
    my $login = $self->login();
    my $cache = $self->_temp_password_cache_object();
    return $cache->get ($login); 
}


=head2 $self->check_temp_password ($pass);

Checks wether the encrypted $pass matches $self->temp_password().

=cut
sub check_temp_password
{
    my $self  = shift || return;
    my $pass  = shift || return;
    my $crypt = crypt ($pass, $self->login());
    return $self->temp_password() eq $crypt;
}


=head2 $self->delete_temp_password();

Deletes the current temporary password.

=cut
sub delete_temp_password
{
    my $self  = shift;
    my $login = $self->login();
    my $cache = $self->_temp_password_cache_object();
    $cache->remove ($login);
}


sub _temp_password_cache_object
{
    return MKDoc::Core::FileCache->instance ('MKDoc::Auth::User::temp_password');
}


1;


__END__
