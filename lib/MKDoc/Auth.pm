package MKDoc::Auth;
use strict;
use warnings;

our $VERSION = 0.4;


__END__


=head1 NAME

MKDoc::Auth - Authentication framework for MKDoc::Core


=head1 INSTALLATION

See L<MKDoc::Setup::Auth>.

Once you're done with the install go to http://<yoursite>/.signup.html to see
how it works.


=head1 INTERFACE

Whenever a user authenticates, the framework will set a user object which can
be accessed in $::MKD_USER.

The $::MKD_USER object MUST have the following methods:

=over 4

=item $object->login() - the login of the user.

=item $object->email() - the email address of the user.

=item $object->full_name() - the full name of the user.

=back

The $::MKD_USER variable can be undefined.

I<That's it>. L<MKDoc::Auth> does not make any other guarantees. Any piece of
code which uses L<MKDoc::Auth> through this interface should be able to use any
other authentication layer provided they implement the simple $::MKD_USER
object described above.


=head1 FUNCTIONALITY 

Installing this product on an L<MKDoc::Core> site will provide the following
services:

=head2 /.signup.html

Open a new account - send a confirmation email

=head2 /.confirm.html?<confirm_id>

Activate / confirm a new account.

=head2 /.login.html

Login / logout / log as someone else.

=head2 /~<login>/.edit.html

Edit user account information.

=head2 /~<login>/.remove.html

Remove user account.

=head2 /.login-recover.html

Recover lost login information - sends an email

=head2 /.password-recover.html

Recover lost password for a given login - sends an email.


=head1 SPECIAL TRICKS

L<MKDoc::Auth> does not use sessions or cookies. It uses plain simple HTTP
authentication.

L<MKDoc::Auth> implement a few tricks to make HTTP authentication possible,
including optional authentication and logout mechanisms. Those tricks are
explained in this paper:

    http://wiki.slugbug.org.uk/HTTP_Authentication


=head1 ADMINISTATION & SECURITY

I have plans to build an autorization framework, L<MKDoc::Authz>, which will be
working independently of L<MKDoc::Auth>.

Since there is no autorization mechanisms in place at the moment, there is
currently no administration interface to manage users. Admin interface would
mean user privileges, user privileges would mean authorization layer.

However, once L<MKDoc::Authz> is done, I plan to release L<MKDoc::Auth::Admin>
which will depend on L<MKDoc::Authz> for privileges management.

Meanwhile, L<MKDoc::Auth> implements a very, very simple policy: a given user
can only modify or delete his own account.


=head1 AUTHOR

Copyright 2003 - MKDoc Holdings Ltd.

Author: Jean-Michel Hiver <jhiver@mkdoc.com>

This module is free software and is distributed under the same license as Perl itself. Use it at your own risk.


=head1 SEE ALSO

L<MKDoc::Auth::User>, L<MKDoc::Auth::TempUser>,
L<MKDoc::Auth::Handler::AuthenticateOpt>,
L<MKDoc::Auth::Handler::Authenticate>, L<MKDoc::Auth::Plugin::Signup>,
L<MKDoc::Auth::Plugin::Confirm>, L<MKDoc::Auth::Plugin::Login>,
L<MKDoc::Auth::Plugin::Edit>, L<MKDoc::Auth::Plugin::Recover_Login>,
L<MKDoc::Auth::Plugin::Recover_Password>, L<MKDoc::Auth::Plugin::Delete>,
L<MKDoc::Core>

Help us open-source MKDoc. Join the mkdoc-modules mailing list:

  mkdoc-modules@lists.webarch.co.uk
