#!/usr/bin/perl

# -----------------------------------------------------------------------------
# driver.pl
# -----------------------------------------------------------------------------
#    Description: Automatically generated MKDoc Site database driver.
#    Note       : ANY CHANGES TO THIS FILE WILL BE LOST!
# -----------------------------------------------------------------------------

use MKDoc::SQL;
MKDoc::SQL::DBH->spawn (
'driver', 'mysql', 'database', 'test', 'user', 'root');
MKDoc::SQL::Table->driver('MySQL');

1;

