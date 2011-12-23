package SQL::Maker::DBICLike;

use strict;
use warnings;
use utf8;

use parent qw(SQL::Maker);

use Class::Accessor::Lite 0.05 (
    rw => [qw/disable_abstract/],
);

our $VERSION = '0.01';

sub select {
    my $self = shift;
    my $stmt;

    if ( !$self->disable_abstract ) {
        my ( $table, $fields, $where, $opt ) = @_;
        # >> copied partly from SQL::Maker
        unless (ref $fields eq 'ARRAY') {
            Carp::croak("SQL::Maker::select_query: \$fields should be ArrayRef[Str]");
        }
        $stmt = $self->new_select(
            select     => $fields,
        );

        unless ( ref $table ) {
            $stmt->add_from( $table );
        }
        else {
            for ( @$table ) {
                $stmt->add_from( ref $_ eq 'ARRAY' ? @$_ : $_ );
            }
        }

        $stmt->prefix($opt->{prefix}) if $opt->{prefix};
        # << copied partly from SQL::Maker

        $stmt->compat_where( $where, $opt );
    }
    else {
        $stmt = $self->select_query(@_);
    }

    return ($stmt->as_sql,@{$stmt->bind});
}


sub new_select {
    my $self = shift;
    my %args = @_==1 ? %{$_[0]} : @_;

    return SQL::Maker::DBICLike::Select->new(
        name_sep   => $self->name_sep,
        quote_char => $self->quote_char,
        new_line   => $self->new_line,
        %args,
    );
}



package SQL::Maker::DBICLike::Select;
use strict;
use parent qw(SQL::Maker::Select);


sub compat_where {
    my ( $self, $where, $attr ) = @_;

    my $cond = $self->abstract_to_maker( $where, $attr->{ abstract_comapt } );

    return $self->add_attr( $attr )->set_where( $cond );
}


sub add_attr {
    my ( $select, $attr ) = @_;

    return $select unless $attr;

    if ( $attr->{ from } ) {
        for my $table ( @{ $attr->{ 'from' } } ) {
            $select->add_from( ref $table ? @$table : $table );
        }
    }

    if ( $attr->{ 'columns' } ) {
        $select->{select} = [];
        for my $col ( @{ $attr->{ 'columns' } } ) {
            $select->add_select(
                ref $col eq 'ARRAY' ? @$col
              : ref $col eq 'HASH'  ? each( %$col ) : $col
            );
        }
    }
    if ( $attr->{ '+columns' } ) {
        for my $col ( @{ $attr->{ '+columns' } } ) {
            $select->add_select(
                ref $col eq 'ARRAY' ? @$col
              : ref $col eq 'HASH'  ? each( %$col ) : $col
            );
        }
    }

    if ( my $order_by = $attr->{ order_by } ) {
        if ( ref( $order_by ) eq 'ARRAY' ) {
            $select->add_order_by( ref( $_ ) ? %{$_} : $_ ) for @$order_by;
        }
        elsif ( ref( $order_by ) eq 'HASH' ) {
            $select->add_order_by( %$order_by );
        }
        else { # foo DESC, bar
            for my $item ( split/\s*,\s*/, $order_by ) {
                $select->add_order_by( split/\s+/, $item );
            }
        }
    }

    if ( my $joins = $attr->{ join } ) {
        $select->{from} = [];
#        my %table = @{ $select->{from} };
#        $select->

        for  ( my $i = 0; $i <= $#{$joins}; $i += 2 ) {
            my ( $table, $join_option ) = ( $joins->[ $i ] , $joins->[ $i + 1 ] );
            if ( ref($table) ) { # table has alias, so add the alias to columns
            }
            $select->add_join( $table, $join_option );
        }
    }

    if ( my $group_by = $attr->{ group_by } ) {
        $select->add_group_by( ref( $_ ) ? %{$_} : $_ ) for @$group_by;
    }

    if ( my $having = $attr->{ having } ) {
        $select->add_having( %$having );
    }

    if ( my $index_hint = $attr->{ index_hint } ) { # TODO
    }

    if ( defined $attr->{ page } or defined $attr->{ rows } ) {
        my ( $rows, $page ) = @{$attr}{qw/rows page/};
        unless ( defined $page and defined $rows ) {
            Carp::croak('page and rows muse be used at once.');
        }
        $select->limit( $rows );
        $select->offset( $rows * ( $page - 1 ) );
    }
    elsif ( defined( my $limit = $attr->{ limit } ) ) {
        $select->limit( $limit );
    }

    if ( defined(  my $offset = $attr->{ offset } ) ) {
        $select->offset( $offset );
    }

    return $select;
}


sub abstract_to_maker {
    my ( $self, $data, $extra_opt ) = @_;
    my $opt = {
        name_sep   => $self->name_sep,
        quote_char => $self->quote_char,
        reduce_parentheses => 1,
        %{ $extra_opt || {} },
    };

    my $ctx = {
        current_level => -1,
        level         => [ {} ],
        key_is_set    => 0,
        cond_opt => {
            name_sep      => '.',
            quote_char    => '',
        },
    };

    $ctx->{ reduce_parentheses }       = $opt->{ reduce_parentheses };
    $ctx->{ cond_opt }->{ name_sep }   = $opt->{ name_sep }   if exists $opt->{ name_sep };
    $ctx->{ cond_opt }->{ quote_char } = $opt->{ quote_char } if exists $opt->{ quote_char };

    _struct_to_cond( $data, $ctx );
}


sub _struct_to_cond {
    my ( $data, $ctx ) = @_;

    if ( ref( $data ) eq 'ARRAY' ) {
        my @items = @$data; # copy for avoiding destruction

        if ( $ctx->{ key_is_set } ) {
            my $cond;

            if ( ($data->[0] || '') eq '-or' and !(ref($data->[1]) eq 'ARRAY')  ) {
                # SQL::Maker does not support [-or => A, B]
                shift @items;
                $cond = _make_cond( $ctx )->add( $ctx->{ key } => shift @items );
                _reduce_parentheses( $cond ) if $ctx->{ reduce_parentheses };

                for ( @items ) {
                    my $following_cond = _make_cond( $ctx )->add( $ctx->{ key } => $_ );
                    _reduce_parentheses( $following_cond ) if $ctx->{ reduce_parentheses };
                    $cond = $cond | $following_cond
                }
            }
            else {
                $cond = _make_cond( $ctx )->add( $ctx->{ key } => $data );
                _reduce_parentheses( $cond ) if $ctx->{ reduce_parentheses };
            }

            $ctx->{ key_is_set } = 0;
            return $cond;
        }

        $ctx->{ current_level }++ unless $ctx->{ key_is_set };

        my $lev = $ctx->{ current_level };

        $ctx->{ level }->[ $lev ]->{ logic } = 'or' unless $ctx->{ level }->[ $lev ]->{ logic };

        my $combined_cond = _struct_to_cond( shift @items, $ctx );

        for my $item ( @items ) {
            my $cond = _struct_to_cond( $item, $ctx );

            next unless $cond;

            if ( $cond && $combined_cond ) {
                if ( $ctx->{ level }->[ $lev ]->{ logic } eq 'and' ) {
                    $combined_cond = $combined_cond & $cond;
                }
                else { # default - or
                    $combined_cond = $combined_cond | $cond;
                }
            }
            else {
                $combined_cond = $cond;
            }
        }

        $ctx->{ current_level }--;

        return $combined_cond;
    }

    elsif ( ref( $data ) eq 'HASH' ) {

        if ( $ctx->{ key_is_set } ) {
            my $cond = _make_cond( $ctx )->add( $ctx->{ key } => $data );
            _reduce_parentheses( $cond ) if $ctx->{ reduce_parentheses };
            $ctx->{ key_is_set } = 0;
            return $cond;
        }

        my $lev = $ctx->{ current_level };

        my $combined_cond;

        for my $key ( keys %$data ) {

            if ( $key eq '-and' or $key eq '-or' ) {
                $ctx->{ level }->[ $ctx->{ current_level }  ]->{ logic } = $key eq '-and' ? 'and' : 'or';
                my $cond = _struct_to_cond( $data->{ $key }, $ctx );
                $ctx->{ level }->[ $ctx->{ current_level }  ]->{ logic } = '';
                if ( $combined_cond ) {
                    if ( $ctx->{ level }->[ $lev ]->{ logic } and $ctx->{ level }->[ $lev ]->{ logic } eq '-or' ) {
                        $combined_cond = $combined_cond | $cond;
                    }
                    else { # default - and
                        $combined_cond = $combined_cond & $cond;
                    }
                }
                else {
                    $combined_cond = $cond;
                }
                next;
            }

            $ctx->{ key } = $key;
            $ctx->{ key_is_set } = 1;

            my $cond = _struct_to_cond( $data->{ $key }, $ctx );

            $ctx->{ key_is_set } = 0;

            if ( $cond && $combined_cond ) {
                if ( $ctx->{ level }->[ $lev ]->{ logic } and $ctx->{ level }->[ $lev ]->{ logic } eq '-or' ) {
                    $combined_cond = $combined_cond | $cond;
                }
                else { # default - and
                    $combined_cond = $combined_cond & $cond;
                }
            }
            else {
                $combined_cond = $cond;
            }
        }

        return $combined_cond;
    }


    elsif ( $data && $data eq '-and' ) {
        $ctx->{ level }->[ $ctx->{ current_level } + 1 ]->{ logic } = 'and';
    }
    elsif ( $data && $data eq '-or' ) {
        $ctx->{ level }->[ $ctx->{ current_level } + 1 ]->{ logic } = 'or';
    }
    else {
        if ( $ctx->{ key_is_set } ) {
            my $cond = _make_cond( $ctx )->add( $ctx->{ key } => $data );
            _reduce_parentheses( $cond ) if $ctx->{ reduce_parentheses };
            $ctx->{ key_is_set } = 0;
            return $cond;
        }
        else {
            $ctx->{ key } = $data;
            $ctx->{ key_is_set } = 1;
            return;
        }
    }

    return;
}


sub _reduce_parentheses {
    $_ =~  s/^\(|\)$//g for @{ $_[0]->{ sql } };
}


sub _make_cond {
    SQL::Maker::Condition->new( %{ $_[0]->{ cond_opt } } );
}

1; # End of SQL::Maker::DBICLike
__END__

=pod

=head1 NAME

SQL::Maker::DBICLike - The great new SQL::Maker::DBICLike!

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

  use SQL::Maker::DBICLike;
  use Test::More;

  my $maker = SQL::Maker::DBICLike->new(driver => 'SQLite', new_line => ' ');
  my ($sql, @bind) = $maker->select( 'foo', ['id'], {-or => [{hoge => 1}, {fuga => 2}], x => 2 } );

  ($sql, @bind) = $maker->select('foo', [\'*'], {}, { order_by => 'bar', limit => 2 });

=head1 DESCRIPTION

This module inherits L<SQL::Maker> and supports L<SQL::Abstract> C<where data> and
L<DBIx::Class::Resultset> C<attribution data>.

=head1 Methods

=head2 $maker = SQL::Maker::DBICLike->new(%attr)

returns SQL::Maker::DBICLike object

=head2 $maker->select($table, $columns, $where, $attr)

same as SQL::Maker but $where is more compatible SQL::Abstract.

=head2 $maker->new_select(%atrr)

returns SQL::Maker::DBICLike::Select object

=head1 Attributions

=head2 columns

=head2 +columns

=head2 order_by

=head2 limit

=head2 rows

=head2 page

=head2 group_by

=head2 join

=head2 having

=head2 from

=head1 SEE ALSO

L<SQL::Maker>, L<SQL::Abstract>, L<DBIx::Class::Resultset>

=head1 AUTHOR

makamaka, C<< <makamaka at cpan.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2011 makamaka.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut


