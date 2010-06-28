use inc::Module::Install;

name     'IhasQuery';
all_from 'lib/IhasQuery.pm';
author   q{John Karr <brainbuz@brainbuz.org>};
license  'gpl';

build_requires 'Test::More';
build_requires 'DBI';
build_requires 'DBD::SQLite'  => '1.29';


auto_install;

WriteAll;

