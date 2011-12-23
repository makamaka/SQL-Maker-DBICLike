
use strict;
use warnings;

use Data::Dumper;
#use SQL::Maker;
#use SQL::Abstract;

use Test::More;
use SQL::Maker::DBICLike;

#use SQL::Maker::Plugin::SQLAbstract::Util;
sub struct_to_cond {
    my ( $data, $opt ) = @_;
    $opt->{ reduce_parentheses } = 0 if !defined $opt->{ reduce_parentheses };
    return SQL::Maker::DBICLike::Select->new->abstract_to_maker( $data, $opt );
}

my $where;
my $cond;

$where = [
    id  => [1,2],
    status => 3,
];

$cond = struct_to_cond( $where, { reduce_parentheses => 1 } );
is( $cond->as_sql, q{(id IN (?, ?)) OR (status = ?)} );
is_deeply( [ $cond->bind ], [qw/1 2 3/] );

$where = [
    -and => [
        status     => 'A',
        status2     => ['A','B'],
        [
            nickname => "key",
            memo     => "key",
        ],
        is_deleted => 0,
    ],
];

$cond = struct_to_cond( $where );
is( $cond->as_sql, q{((((status = ?)) AND ((status2 IN (?, ?)))) AND (((nickname = ?)) OR ((memo = ?)))) AND ((is_deleted = ?))} );
is_deeply( [ $cond->bind ], [qw/A A B key key 0/] );

$cond = struct_to_cond( $where, { reduce_parentheses => 1 } );
is( $cond->as_sql, q{(((status = ?) AND (status2 IN (?, ?))) AND ((nickname = ?) OR (memo = ?))) AND (is_deleted = ?)} );
is_deeply( [ $cond->bind ], [qw/A A B key key 0/] );


$where = [
    id  => [-or => 1,2],
    status2 => 3,
    status => {'!=' => 'A'}
];

$cond = struct_to_cond( $where );
is( $cond->as_sql, q{((((id = ?)) OR ((id = ?))) OR ((status2 = ?))) OR ((status != ?))} );
is_deeply( [ $cond->bind ], [qw/1 2 3 A/] );

$cond = struct_to_cond( $where, { reduce_parentheses => 1 } );
is( $cond->as_sql, q{(((id = ?) OR (id = ?)) OR (status2 = ?)) OR (status != ?)} );
is_deeply( [ $cond->bind ], [qw/1 2 3 A/] );


$where = [
    id  => [-and => 1,2],
    status2 => 3,
    status => {'!=' => 'A'}
];

$cond = struct_to_cond( $where );
is( $cond->as_sql, q{((((id = ?) AND (id = ?))) OR ((status2 = ?))) OR ((status != ?))} );
is_deeply( [ $cond->bind ], [qw/1 2 3 A/] );

$cond = struct_to_cond( $where, { reduce_parentheses => 1 } );
is( $cond->as_sql, q{(((id = ?) AND (id = ?)) OR (status2 = ?)) OR (status != ?)} );
is_deeply( [ $cond->bind ], [qw/1 2 3 A/] );


$where = [
    -and => [
        id     => [-or  => 1,2],
        status => [-and => {'!=' => 'A'}, {'!=' => 'B'} ],
    ],
    -or => [
        id2     => [-and  => 3,4],
        status2 => [-and => {'!=' => 'C'}, {'!=' => 'D'} ],
    ],
    -and => [
        id3     => [-or  => 5,6],
        status3 => [-or => {'!=' => 'E'}, {'!=' => 'F'} ],
    ],
];

$cond = struct_to_cond( $where );
is( $cond->as_sql,
    q{(((((id = ?)) OR ((id = ?))) AND (((status != ?) AND (status != ?)))) OR ((((id2 = ?) AND (id2 = ?))) OR (((status2 != ?) AND (status2 != ?))))) OR ((((id3 = ?)) OR ((id3 = ?))) AND (((status3 != ?)) OR ((status3 != ?))))} );
is_deeply( [ $cond->bind ], [qw/1 2 A B 3 4 C D 5 6 E F/] );

$cond = struct_to_cond( $where, { reduce_parentheses => 1 } );
is( $cond->as_sql,
    q{((((id = ?) OR (id = ?)) AND ((status != ?) AND (status != ?))) OR (((id2 = ?) AND (id2 = ?)) OR ((status2 != ?) AND (status2 != ?)))) OR (((id3 = ?) OR (id3 = ?)) AND ((status3 != ?) OR (status3 != ?)))} );
is_deeply( [ $cond->bind ], [qw/1 2 A B 3 4 C D 5 6 E F/] );


$where = {
    id     => {'!=' => 'A'},
    status => [-or => 1,{'!=' => 10}],
};
$cond = struct_to_cond( $where );
#diag( $cond->as_sql );
like( $cond->as_sql, qr/\Q(id != ?)\E/ );
like( $cond->as_sql, qr/\Q((status = ?)) OR ((status != ?))\E/ );
#print $cond->bind;


done_testing;

__END__
