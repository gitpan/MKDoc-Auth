#!/usr/bin/perl
use lib qw (lib ../lib);
use Test::More 'no_plan';
use strict;
use warnings;
use MKDoc::Core::Error;
use MKDoc::Auth::User;
use MKDoc::SQL;

ok (1);
exit (0) unless (-e 'test/su/driver.pl');

$ENV{SITE_DIR} = 'test';

our @ERRORS = ();

$MKDoc::Core::Error::CALLBACK = sub {
    push @ERRORS, shift;
};


MKDoc::SQL::Table->load_state ('test/su');
my ($user_t) = MKDoc::Auth::User->sql_schema();
ok ($user_t => 'MKDoc::Auth::User::sql_schema()');

eval { $user_t->drop()   };
$user_t->create();

my $user = new MKDoc::Auth::User (
    login       => 'chris',
    email       => 'chris@mkdoc.com',
    full_name   => 'Chris Croome',
    password_1  => 'complicated long password',
    password_2  => 'complicated long password',
);

ok ($user => 'MKDoc::Auth::User::new()');
ok (!$user->check_password ('test a wrong password') => 'password check fail');
ok ($user->check_password ('complicated long password') => 'password check pass');

__END__

MKDoc::SQL::Table->load_state ('test/su');
MKDoc::Auth::User->sql_schema();
MKDoc::SQL::Table->save_state ('test/su');
ok (-e 'test/su/MKDoc_Auth_User.def' => 'deploy schema');
