use 5.008;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'SQL::Maker::DBICLike',
    AUTHOR              => q{makamaka <makamaka@cpan.org>},
    VERSION_FROM        => 'lib/SQL/Maker/DBICLike.pm',
    ABSTRACT_FROM       => 'lib/SQL/Maker/DBICLike.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => '0.98',
        'SQL::Maker' => '1.03',
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'SQL-Maker-DBICLike-*' },
);

