=head1 package MKDoc::Setup::Auth

Install L<MKDoc::Auth> on an L<MKDoc::Core> site.


=head1 REQUIREMENTS

=head2 MKDoc::Core

Make sure you have installed L<MKDoc::Core> on your system with at least one
L<MKDoc::Core> site.  Please refer to L<MKDoc::Core::Article::Install> for
details on how to do this.


=head2 MKDoc::SQL

L<MKDoc::Auth> use an SQL table to make its data persistent. You need to make
sure that you have installed L<MKDoc::SQL> on the website for which you want to
install L<MKDoc::Auth>.

See L<MKDoc::Setup::SQL> for more details.


=head1 Installing MKDoc::Auth

Once you are sure that L<MKDoc::Core> and L<MKDoc::SQL> have been properly
installed on your site, installation is trivial:

  source /path/to/site/mksetenv.sh
  perl -MMKDoc::Setup -e install_auth

That's it! The install script will create the SQL tables, register the
MKDoc::Auth plugins, and fiddle with apache config files as appropriate. Once
you are done you just need to restart apache.

=cut
package MKDoc::Setup::Auth;
use strict;
use warnings;
use File::Spec;
use File::Touch;
use MKDoc::SQL;
use base qw /MKDoc::Setup/;
use MKDoc::Auth::User; 


sub main::install_auth
{
    $ENV{MKDOC_DIR} || die "\$ENV{MKDOC_DIR} is not defined!";
    $ENV{SITE_DIR}  || die "\$ENV{SITE_DIR} is not defined!";
    -e "$ENV{SITE_DIR}/su/driver.pl" || die "$ENV{SITE_DIR}: MKDoc::SQL service does not seems to be installed.";
    
    MKDoc::SQL::Table->load_state ("$ENV{SITE_DIR}/su");
    MKDoc::Auth::User->sql_schema();
    MKDoc::SQL::Table->save_state ("$ENV{SITE_DIR}/su");
    print "Added SQL schema\n";

    __PACKAGE__->new()->install();
}


sub keys { qw /SITE_DIR NAME USER PASS HOST PORT/ }


sub label
{
    my $self = shift;
    $_ = shift;
    /SITE_DIR/    and return "Site Directory";
    /NAME/        and return "Database Name";
    /USER/        and return "Database User";
    /PASS/        and return "Database Password";
    /HOST/        and return "Database Host";
    /PORT/        and return "Database Port";
    return;
}


sub install
{
    my $self = shift;

    my $user_t = MKDoc::Auth::User->sql_table();
    eval { $user_t->create() };

    print "Attempting to create " . MKDoc::Auth::User->sql_name() . "\n";
    while ($@)
    {
        print "Could not create " . MKDoc::Auth::User->sql_name() . "\n";
        print "Error: $@\n\n";

        print "Would you like to:\n";
        print "T - Try again\n";
        print "I - Ignore and continue\n";
        print "E - Erase the existing table\n";
        
        my $answer = lc (<STDIN>);
        chomp ($answer);
       
        $answer eq 'i' and last;
        $answer eq 'e' and do {
            eval { $user_t->drop() }
        };

        $@ = undef;
        eval { $user_t->create() };
    }

    my @plugins = qw ( 
MKDoc::Auth::Plugin::Confirm
MKDoc::Auth::Plugin::Edit
MKDoc::Auth::Plugin::Login
MKDoc::Auth::Plugin::Recover_Login
MKDoc::Auth::Plugin::Recover_Password
MKDoc::Auth::Plugin::Remove
MKDoc::Auth::Plugin::Signup
    );

    for (@plugins) { _register_plugin ($_) } 

    _register_httpd ("$ENV{SITE_DIR}/httpd/httpd-fixup.conf");
    print "Registered MKDoc::Auth::Handler::AuthenticateOpt (Apache)\n";

    _register_httpd ("$ENV{SITE_DIR}/httpd2/httpd-fixup.conf");
    print "Registered MKDoc::Auth::Handler::AuthenticateOpt (Apache 2)\n";
}


sub _register_plugin
{
    my $plugin = shift;
    File::Touch::touch ("$ENV{SITE_DIR}/plugin/50000_$plugin");
    print "Registered $plugin\n";
}


sub _register_httpd
{
    my $file = shift;

    open FP, "<$file" or die "Cannot read $file";
    my $data = join '', <FP>;
    close FP;

    $data =~ /\# MKDoc::Auth/ and return;

    $data .= <<EOF;

# MKDoc::Auth
<Location />
  PerlFixupHandler MKDoc::Auth::Handler::AuthenticateOpt
</Location>
EOF

    open FP, ">$file" or die "Cannot write $file";
    print FP $data;
    close FP;
}


1;
