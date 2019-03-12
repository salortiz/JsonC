use v6;

need JsonC;
use JSON::Fast;

# An speed test.
my $JSON = "$*HOME/.zef/store/projects1.json";
if $JSON.IO.e {
    with $JSON {
	say "Testing with $_ ({$_.IO.s})";
	say "Trying to read with JsonC (raw):";
	{
	    my $start = now;
	    my @a := JsonC::JSON.new-from-file($_);
	    say "Last module is '{@a[@a.elems-1]<description>}";
	    say "Parsed in { now - $start }s. @a.elems() projects";
	    my $s1 = now;
	    my %b = @a.first({$_<name> eq 'DBIish'});
	    say "DBDish '%b<description>' located in { now - $s1 }s";
	    say "Total time: { now - $start }";
	}
	say "---";
	say "Trying to read with JsonC (unmarshaled):";
	{
	    my $start = now;
	    my @a := JsonC::JSON.new-from-file($_).Perl;
	    say "Last module is '{@a[@a.elems-1]<description>}";
	    say "Parsed in { now - $start }s. @a.elems() projects";
	    my $s1 = now;
	    my %b = @a.first({$_<name> eq 'DBIish'});
	    say "DBDish '%b<description>' located in { now - $s1 }s";
	    say "Total time: { now - $start }";
	}
	say "---";
	say "Trying to read with JSON::Fast";
	{
	    my $start = now;
	    my @a := from-json($_.IO.slurp);
	    say "Last module is '{@a[@a.elems-1]<description>}";
	    say "Parsed in { now - $start }s. @a.elems() projects";
	    my $s1 = now;
	    my %b = @a.first({$_<name> eq 'DBIish'});
	    say "DBDish '%b<description>' located in { now - $s1 }s";
	    say "Total time: { now - $start }";
	}
    }
}



