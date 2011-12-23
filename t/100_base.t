
use strict;
use warnings;
#use SQL::Abstract;

use Test::More;
use SQL::Maker::DBICLike;

my $cond;

sub struct_to_cond {
    my ( $data, %opt ) = @_;
    $opt{ reduce_parentheses } = 0 if !defined $opt{ reduce_parentheses };
    return SQL::Maker::DBICLike::Select->new->abstract_to_maker( $data, \%opt );
}


$cond = struct_to_cond( { foo => 'bar' } );
isa_ok( $cond, 'SQL::Maker::Condition' );
is( $cond->as_sql, q{(foo = ?)} );
is_deeply( [ $cond->bind ], [qw/bar/] );

$cond = struct_to_cond( { foo => 'bar', bar => 'baz' } );
isa_ok( $cond, 'SQL::Maker::Condition' );
like( $cond->as_sql, qr{\Q((foo = ?)) AND ((bar = ?))\E|\Q((bar = ?)) AND ((foo = ?))\E} );
like( join( ',', $cond->bind ), qr/bar,baz|baz,bar/ );

$cond = struct_to_cond( { foo  => {'!=' => 'bar'} } );
is( $cond->as_sql, q{(foo != ?)} );
is_deeply( [ $cond->bind ], [qw/bar/] );

$cond = struct_to_cond( [ foo => 'bar' ] );
is( $cond->as_sql, q{(foo = ?)} );
is_deeply( [ $cond->bind ], [qw/bar/] );

$cond = struct_to_cond( { status => ['foo','bar'] } );
is( $cond->as_sql, q{(status IN (?, ?))} );
is_deeply( [ $cond->bind ], [qw/foo bar/] );

$cond = struct_to_cond( { status => [-or => 'foo','bar'] } );
is( $cond->as_sql, q{((status = ?)) OR ((status = ?))} );
is_deeply( [ $cond->bind ], [qw/foo bar/] );

$cond = struct_to_cond( { status => [-and => 'foo','bar'] } );
is( $cond->as_sql, q{((status = ?) AND (status = ?))} );
is_deeply( [ $cond->bind ], [qw/foo bar/] );


done_testing;

__END__

$cond = SQL::Maker::Condition->new(
        name_sep   => '.',
        quote_char => '',
)->add( [ foo => 'bar' ] );
is( $cond->as_sql, q{(foo = ?)} );
is_deeply( [ $cond->bind ], [qw/bar/] );

my ( $sql, @binds );

my $where;

$where = [
    id  => [1,2],
    status => 3,
];
is( struct_to_cond( $where )->as_sql, q{((id IN (?, ?))) OR ((status = ?))} );

$where = {
    id  => {'!=' => 'A'},
};
is( struct_to_cond( $where )->as_sql, q{(id != ?)} );
is_deeply( [ struct_to_cond( $where )->bind ], ['A'] );

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
is( struct_to_cond( $where )->as_sql, q{((((status = ?)) AND ((status2 IN (?, ?)))) AND (((nickname = ?)) OR ((memo = ?)))) AND ((is_deleted = ?))} );
is_deeply( [ struct_to_cond( $where )->bind ], [qw/A A B key key 0/] );


$where = [
    id  => [-or => 1,2],
    status2 => 3,
    status => {'!=' => 'A'}
];
is( struct_to_cond( $where )->as_sql, q{((((id = ?)) OR ((id = ?))) OR ((status2 = ?))) OR ((status != ?))} );
is_deeply( [ struct_to_cond( $where )->bind ], [qw/1 2 3 A/] );


$where = [
    id  => [-and => 1,2],
    status2 => 3,
    status => {'!=' => 'A'}
];
is( struct_to_cond( $where )->as_sql, q{((((id = ?) AND (id = ?))) OR ((status2 = ?))) OR ((status != ?))} );
is_deeply( [ struct_to_cond( $where )->bind ], [qw/1 2 3 A/] );


#is( struct_to_cond( $where )->as_sql, q{} );

( $sql, @binds ) = SQL::Abstract->new->where($where);
#print $sql,"\n";

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

is( struct_to_cond( $where )->as_sql, 
    q{(((((id = ?)) OR ((id = ?))) AND (((status != ?) AND (status != ?)))) OR ((((id2 = ?) AND (id2 = ?))) OR (((status2 != ?) AND (status2 != ?))))) OR ((((id3 = ?)) OR ((id3 = ?))) AND (((status3 != ?)) OR ((status3 != ?))))}
);
is_deeply( [ struct_to_cond( $where )->bind ], [qw/1 2 A B 3 4 C D 5 6 E F/] );

$where = {
    status => [ -or => 1, {'!=' => 10} ],
};

is( struct_to_cond( $where )->as_sql, q{((status = ?)) OR ((status != ?))} );
is_deeply( [ struct_to_cond( $where )->bind ], [qw/1 10/] );


$where = {
    id     => {'!=' => 'A'},
    status => [-or => 1,{'!=' => 10}],
};
( $sql, @binds ) = SQL::Abstract->new->where($where);


like( struct_to_cond( $where )->as_sql, qr/\Q(id != ?)\E/ );
like( struct_to_cond( $where )->as_sql, qr/\Q((status = ?)) OR ((status != ?))\E/ );
#like( struct_to_cond( $where )->as_sql, qr/\Q(status = ? OR status != ?)\E/ );


$where = [
    id  => [1,2],
    status => 3,
];
is( struct_to_cond2( $where )->as_sql, q{(id IN (?, ?)) OR (status = ?)} );

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
is( struct_to_cond2( $where )->as_sql,
    q{(((status = ?) AND (status2 IN (?, ?))) AND ((nickname = ?) OR (memo = ?))) AND (is_deleted = ?)} );
is_deeply( [ struct_to_cond( $where )->bind ], [qw/A A B key key 0/] );

done_testing;

# TODO
# status => { '=', ['assigned', 'in-progress', 'pending'] };
# status => { '!=', 'completed', -not_like => 'pending%' }
# reportid => { -in => [567, 2335, 2] }



( $sql, @binds ) = SQL::Abstract->new->where($where);
#print $sql,"\n";
#print  struct_to_cond( $where )->as_sql, "\n";
#print Dumper(struct_to_cond( $where )->bind);


sub struct_to_cond2 {
    my ( $data ) = @_;
    _struct_to_cond( $data, { current_level => -1, level => [{}], key_is_set => 0, reduce_parentheses => 1 } );
}

sub struct_to_cond {
    my ( $data ) = @_;
    _struct_to_cond( $data,  { current_level => -1, level => [{}], key_is_set => 0 } );
}

sub _struct_to_cond {
    my ( $data, $opt ) = @_;

#    print STDERR $opt->{ current_level },"\t",$opt->{ key_is_set } ,"\t",$data,"-\n";

    if ( ref( $data ) eq 'ARRAY' ) {
        my @items = @$data; # copy for avoiding destruction

        if ( $opt->{ key_is_set } ) {
            my $cond;
            if ( ($data->[0] || '') eq '-or' and !(ref($data->[1]) eq 'ARRAY')  ) {
                # SQL::Maker does not support [-or => A, B]
                shift @items;
                $cond = make_cond()->add( $opt->{ key } => shift @items );

                if ( $opt->{ reduce_parentheses } ) {
                    $_ =~  s/^\(|\)$//g for @{ $cond->{ sql } };
                }

                for ( @items ) {
                    $cond = $cond | make_cond()->add( $opt->{ key } => $_ );
                    if ( $opt->{ reduce_parentheses } ) {
                        $_ =~  s/^\(|\)$//g for @{ $cond->{ sql } };
                    }
                }
            }
            else {
                $cond = make_cond()->add( $opt->{ key } => $data );
                if ( $opt->{ reduce_parentheses } ) {
                    $_ =~  s/^\(|\)$//g for @{ $cond->{ sql } };
                }
            }
            $opt->{ key_is_set } = 0;
            return $cond;
        }

        $opt->{ current_level }++ unless $opt->{ key_is_set };

        my $lev = $opt->{ current_level };

        $opt->{ level }->[ $lev ]->{ logic } = 'or' unless $opt->{ level }->[ $lev ]->{ logic };

        my $combined_cond = _struct_to_cond( shift @items, $opt );

        for my $item ( @items ) {
            my $cond = _struct_to_cond( $item, $opt );

            next unless $cond;

            if ( $cond && $combined_cond ) {
                if ( $opt->{ level }->[ $lev ]->{ logic } eq 'and' ) {
                    $combined_cond = $combined_cond & $cond;
                }
                else {
                    $combined_cond = $combined_cond | $cond;
                }
            }
            else {
                $combined_cond = $cond;
            }
        }

        $opt->{ current_level }--;

        return $combined_cond;
    }

    elsif ( ref( $data ) eq 'HASH' ) {

        if ( $opt->{ key_is_set } ) {
            my $cond = make_cond()->add( $opt->{ key } => $data );
            $opt->{ key_is_set } = 0;
            return $cond;
        }

        my $lev = $opt->{ current_level };

        my $combined_cond;

        for my $key ( keys %$data ) {
            $opt->{ key } = $key;
            $opt->{ key_is_set } = 1;
            my $cond = _struct_to_cond( $data->{ $key }, $opt );

            $opt->{ key_is_set } = 0;

            if ( $cond && $combined_cond ) {
                if ( $opt->{ level }->[ $lev ]->{ logic } ) {
                    $combined_cond = $combined_cond & $cond;
                }
                else {
                    $combined_cond = $combined_cond | $cond;
                }
            }
            else {
                $combined_cond = $cond;
            }
        }

        return $combined_cond;
    }


    elsif ( $data eq '-and' ) {
        $opt->{ level }->[ $opt->{ current_level } + 1 ]->{ logic } = 'and';
    }
    elsif ( $data eq '-or' ) {
        $opt->{ level }->[ $opt->{ current_level } + 1 ]->{ logic } = 'or';
    }
    else {
        if ( $opt->{ key_is_set } ) {
            my $cond = make_cond()->add( $opt->{ key } => $data );
            if ( $opt->{ reduce_parentheses } ) {
                $_ =~  s/^\(|\)$//g for @{ $cond->{ sql } };
            }
            $opt->{ key_is_set } = 0;
            return $cond;
        }
        else {
            $opt->{ key } = $data;
            $opt->{ key_is_set } = 1;
            return;
        }
    }

    return;
}


sub make_cond {
    SQL::Maker::Condition->new(
        name_sep   => '.',
        quote_char => '',
    );
}
