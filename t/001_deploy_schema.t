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

MKDoc::SQL::Table->load_state ('test/su');
MKDoc::Auth::User->sql_schema();
MKDoc::SQL::Table->save_state ('test/su');
ok (-e 'test/su/MKDoc_Auth_User.def' => 'deploy schema');


1;
