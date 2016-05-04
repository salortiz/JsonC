use v6;
use Test;

plan 22;

use-ok 'JsonC';

my $Str = '{ "foo": "mamá", "arr": [ 1, 4, 10 ] }';

my \JSON = ::('JsonC::JSON');

ok JSON !~~ Failure, 'Class JSON ready';

my $json = JSON.new($Str);

ok $json, "Created";
isa-ok $json,	JSON;
does-ok $json,  Associative;

is $json.Str, $Str,  "The spected Str";

is $json.elems,  2,	     'Two elems';

isa-ok $json.get-type, Hash, "Expected type (Hash)";

ok Hash ~~ $json,	     "Smart match";  # Please note the order

ok $json<foo>:exists,	     'Exists';

is $json<foo>, 'mamá',	     "Expected '$json<foo>'";

nok $json<bar>:exists,	    'Not exists';

ok (my @a := $json<arr>),   'arr exists';

isa-ok @a,   JSON;

does-ok @a,  Positional;

isa-ok @a.get-type, Array,  "Expected type (Array)";

ok Array ~~ @a,		    "Smart match works";  # Please note the order

is ~@a, "[ 1, 4, 10 ]",	    "Seems good: @a[]";

is @a.elems,  3,	    'size';
is +@a,       3,	    'via cohersion';

is @a[1],  4,		    'a four';

# An speed test.
my sub findProyectsFile(Str $prefix?) {
    my (@repos, $target, $pandadir);
    if defined $prefix {
	@repos.push: CompUnit::RepositoryRegistry.repository-for-spec($prefix);
    }
    @repos.append: <site home>.map({CompUnit::RepositoryRegistry.repository-for-name($_)});
    @repos.=grep(*.defined);
    for @repos {
	$target = $_;
	$pandadir = $target.prefix.child('panda');
	try $pandadir.mkdir;
	last if $pandadir.w;
    }
    if $pandadir.w && $pandadir.child('projects.json') -> $_ {
	$_.f && $_;
    } else { Nil }
}

with findProyectsFile() -> $_ {
    diag "Trying to read $_";
    my $start = now;
    ok (my $pf = JSON.new-from-file($_)),   'Can read file';
    diag "Parsed in { now - $start }s. $pf.elems() projects";

    my @a = $pf.Array;
    for @a.pick(10) {
	say $_<description>;
    }

} else {
    skip 'No file for test',  1;
}


