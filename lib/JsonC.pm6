use v6;

unit module JsonC:ver<0.0.1>:auth<salortiz>;
use NativeLibs;
use nqp;

INIT {
    my $Lib = NativeLibs::Loader.load('libjson-c.so.2');
}

enum json_type <
  type-null type-boolean type-double type-int
  type-object type-array type-string
>;

constant type-map = Map.new(
    0 => Nil, 1 => Bool, 2 => Num, 3 => Int,
    4 => Hash, 5 => Array, 6 => Str
);

enum json_tokener_error <
  json_tokener_success json_tokener_continue json_tokener_error_depth
  json_tokener_error_parse_eof json_tokener_error_parse_unexpected
  json_tokener_error_parse_null json_tokener_error_parse_boolean
  json_tokener_error_parse_number json_tokener_error_parse_array
  json_tokener_error_parse_object_key_name json_tokener_error_parse_object_key_sep
  json_tokener_error_parse_object_value_sep json_tokener_error_parse_string
  json_tokener_error_parse_comment json_tokener_error_size
>;

enum json_tokener_state <
  json_tokener_state_eatws json_tokener_state_start json_tokener_state_finish
  json_tokener_state_null json_tokener_state_comment_start json_tokener_state_comment
  json_tokener_state_comment_eol json_tokener_state_comment_end
  json_tokener_state_string json_tokener_state_string_escape
  json_tokener_state_escape_unicode json_tokener_state_boolean
  json_tokener_state_number json_tokener_state_array json_tokener_state_array_add
  json_tokener_state_array_sep json_tokener_state_object_field_start
  json_tokener_state_object_field json_tokener_state_object_field_end
  json_tokener_state_object_value json_tokener_state_object_value_add
  json_tokener_state_object_sep json_tokener_state_array_after_sep
  json_tokener_state_object_field_start_after_sep json_tokener_state_inf
>;

constant JSON_OBJECT_DEF_HASH_ENTRIES =  16;
constant JSON_C_TO_STRING_PLAIN	=         0;
constant JSON_C_TO_STRING_SPACED = (1 +< 0);
constant JSON_C_TO_STRING_PRETTY = (1 +< 1);
constant JSON_C_TO_STRING_NOZERO = (1 +< 2);

sub err-desc(uint32 -->Str) is symbol('json_tokener_error_desc') is native { * }

my class JSON-P is repr('CPointer') { ... }
my class JSON-A is repr('CPointer') { ... }

our class JSON is repr('CPointer') {

    my class Tokener is repr('CPointer') {

	my class i-tokener is repr('CStruct') {
	    has Str $.str;
	    has int64 $.pb;
	    has int32 $.max_depth;
	    has int32 $.depth;
	    has int32 $.is_double;
	    has int32 $.st_pos;
	    has int32 $.char_offset;
	}

	sub json_tokener_new(-->Tokener) is native { * }
	sub json_tokener_set_flags(Tokener,int32) is native { * }
	method new(:$strict) {
	    with json_tokener_new() {
		json_tokener_set_flags($_, 0x01) if $strict;
		$_;
	    } else { Nil }
	}
	method free() is symbol('json_tokener_free') is native { * }
	method get-err(-->uint32) is symbol('json_tokener_get_error') is native { * }
	method internal() {
	    nativecast(i-tokener, self);
	}
    }

    my class lh_entry is repr('CStruct') {
	has Str $.k;
	has JSON $.v;
	has lh_entry $.next;
	has lh_entry $.prev;
    }

    my class lh_table is repr('CStruct') {
	has int32 $.size;
	has int32 $.count;
	has int32 $.collisions;
	has int32 $.resizes;
	has int32 $.lookups;
	has int32 $.inserts;
	has int32 $.deletes;
	has Str   $.name;
	has lh_entry $.head;
	has lh_entry $.tail;
    }

    method json_object_get_object(-->lh_table) is native { * };
    sub json_object_get_string(JSON --> Str) is native { * }
    sub json_object_get_boolean(JSON --> uint32) is native { * }
    sub json_object_get_int64(JSON --> uint64) is native { * }
    sub json_object_get_double(JSON --> num64) is native { * }
    sub json_object_array_length(JSON -->uint32) is native { * };
    sub json_object_array_get_idx(JSON, uint32 -->JSON) is native { * };
    method unmarshal(:$perl) {
	# We don't use the json_type enum for speed.
	given self.get_type {
	    when 0 { Any }
	    when 1 { Bool(json_object_get_boolean(self)) }
	    when 2 { json_object_get_double(self).Rat } #FIXME Rat!?
	    when 3 { json_object_get_int64(self) }
	    when 4 { # Associative
		if $perl {
		    my %a;
		    my $head = self.json_object_get_object.head;
		    while $head.defined {
			my $v = $head.v;
			%a{$head.k} = $v.defined ?? $v.unmarshal(:perl) !! Any;
			$head = $head.next;
		    }
		    %a;
		} else {
		    nativecast(JSON-A, self)
		}
	    }
	    when 5 { #Positional
		if $perl {
		    my @a;
		    my $elems = json_object_array_length(self);
		    for ^$elems {
			with json_object_array_get_idx(self, $_) {
			    @a.push: .unmarshal(:perl);
			}
			else {
			    @a.push: Any
			}
		    }
		    @a;
		} else {
		    nativecast(JSON-P, self)
		}
	    }
	    when 6 { json_object_get_string(self) }
	}
    }

    sub json_object_new_object(-->JSON) is native { * }
    sub json_object_new_string(Str --> JSON) is native { * }
    sub json_object_new_int64(int64 --> JSON) is native { * }
    sub json_object_new_boolean(int32 --> JSON) is native { * }
    sub json_object_new_double(num64 --> JSON) is native { * }
    sub json_object_new_array(--> JSON) is native { * }
    sub json_object_array_add(JSON, JSON --> int32) is native { * }
    sub json_object_object_add(JSON, Str, JSON) is native { * }
    method marshal(Any \v) {
	given v {
	    when JSON { self }
	    when Str { json_object_new_string($_) }
	    when Bool { json_object_new_boolean(+$_) }
	    when Int { json_object_new_int64($_) }
	    when Num { json_object_new_double($_) }
	    when Rat { json_object_new_double(.Num) }
	    when Associative {
		my \obj = json_object_new_object();
		for %($_) -> (:key($k), :value($v)) {
		    json_object_object_add(obj, $k,
			($v.defined ?? JSON.marshal($v) !! JSON)
		    );
		}
		obj;
	    }
	    when Positional {
		my \arr = json_object_new_array();
		when Iterable {
		    for @($_) {
			json_object_array_add(arr,
			    $_.defined ?? JSON.marshal($_) !! JSON
			);
		    }
		    arr;
		}
		default {
		    for ^($_.elems) {
			with v[$_] {
			    json_object_array_add(arr, JSON.marshal($_));
			} else {
			    json_object_array_add(arr, JSON);
			}
		    }
		    arr;
		}
	    }
	    default { JSON }
	}
    }

    multi method new(JSON:) {
	json_object_new_object();
    }

    sub json_object_put(JSON) is native { * }
    method dispose(JSON:D:) {
	json_object_put(self);
    }

    sub json_object_from_file(Str -->JSON) is native { * }
    multi method new-from-file(Str() $path) {
	with json_object_from_file($path)  {
	    .unmarshal;
	} else {
	    # TODO Make typed exception
	    fail 'JSON: Error';
	}
    }

    sub json_tokener_parse_ex(Tokener, utf8, int32 -->JSON) is native { * }
    multi method new(utf8 $buf, :$strict) {
	my $tok = Tokener.new(:$strict);
	LEAVE { .free with $tok }
	with json_tokener_parse_ex($tok, $buf, $buf.bytes) {
	    if $strict {
		my $i = $tok.internal;
	    }
	    .unmarshal;
	} else {
	    # TODO Make typed exception
	    my $err = $tok.get-err;
	    fail 'JSON: ' ~ err-desc($err);
	}
    }

    multi method new(Str $str, :$strict = True) {
	#fail "Ilegal char" if $strict && $str ~~ / \t /;
	self.new($str.encode, :$strict)
    }

    sub json_object_to_file_ex(Str, JSON, uint32 -->uint32) is native { * }
    method to-file(Str() $path) {
	json_object_to_file_ex($path, self, 0);
    }

    sub json_object_to_json_string_ext(JSON, uint32 -->Str) is native { * }
    multi method Str(JSON:D: :$pretty) {

	my $flags = JSON_C_TO_STRING_SPACED;
	$flags = $pretty ?? JSON_C_TO_STRING_PRETTY !! JSON_C_TO_STRING_PLAIN
	    if $pretty.defined;
	json_object_to_json_string_ext(self, $flags);
    }

    method get_type(--> int32) is symbol('json_object_get_type') is native { * }
    method get-type(JSON:D:) {
	type-map{self.get_type};
    }

    multi method ACCEPTS(JSON:D: Mu \t) {
	self.get-type ~~ t;
    }

    multi method Numeric(JSON:D:) {
	self.elems;
    }

}

class JSON-P is JSON does Positional does Iterable {
    sub json_object_array_length(JSON -->uint32) is native { * };
    method elems() {
	json_object_array_length(self);
    }

    sub json_object_array_get_idx(JSON, uint32 -->JSON) is native { * };
    method AT-POS(Int() $idx) {
	with json_object_array_get_idx(self, $idx) {
	    .unmarshal;
	} else { Nil }
    }

    method iterator() {
	(gather {
	    my $elems = self.elems;
	    my int $i = 0;
	    while $i < $elems {
		take self.AT-POS($i);
		++$i;
	    }
	}).iterator;
    }

    method Array() {
	Array.from-iterator(self.iterator);
    }
}

class JSON-A is JSON does Associative does Iterable {
    sub json_object_object_get_ex(JSON, Str, JSON is rw -->uint32) is native { * };
    multi method AT-KEY(Str $key) {
	my JSON $new = JSON.bless;
	if json_object_object_get_ex(self, $key, $new) {
	    $new.unmarshal;
	}
	else { Nil }
    }

    method EXISTS-KEY(Str $key) {
	Bool(json_object_object_get_ex(self, $key, JSON));
    }

    sub json_object_object_length(JSON --> int32) is native { * };
    method elems() {
	json_object_object_length(self);
    }

    method pairs() {
	my $lht = self.json_object_get_object;
	my $head = $lht.head;
	gather { while $head.defined {
	    my $v = $head.v;
	    take ($head.k => ($v.defined ?? $v.unmarshal !! Any));
	    $head = $head.next;
	} }
    }
    method iterator {
	self.pairs.iterator;
    }
}

sub from-json(Str $json) is export {
    with JSON.new($json) {
	.unmarshal(:perl);
    } else {
	.fail;
    }
}

sub to-json(Any \v, :$pretty) is export {
    JSON.marshal(v).Str(:$pretty);
}

