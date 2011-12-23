

use strict;
use SQL::Maker::DBICLike;
use Test::More;

my $maker = SQL::Maker::DBICLike->new(driver => 'SQLite', new_line => ' ');

my ($sql, @bind) = $maker->select( 'hoge', ['id'], {-or => [{hoge => 1}, {fuga => 2}], x => 2 } );
#print $sql,"\n";
is($sql, q{SELECT "id" FROM "hoge" WHERE (("hoge" = ?) OR ("fuga" = ?)) AND ("x" = ?)});

($sql, @bind) = $maker->select( 'hoge', ['id'], {-and => [{hoge => 1}, {fuga => 2}], x => 2 } );
#print $sql,"\n";
is($sql, q{SELECT "id" FROM "hoge" WHERE (("hoge" = ?) AND ("fuga" = ?)) AND ("x" = ?)});

done_testing;

