#!/usr/bin/env perl6

use v6;

use P5pack;

my $num-glyphs = -1;
my $number-of-hmetrics = -1;

sub read-generic-table($table, $length, @table-definition) {
  my $index = 0;
  my %args;
  for @table-definition -> $pair {
    my ($name, $type) = $pair.kv;
    given $type {
      when 'uint16' {
        %args{$name} = (unpack 'n', $table.subbuf($index, 2))[0];
        $index += 2;
      }
      when 'int16' {
        %args{$name} = (unpack 'n', $table.subbuf($index, 2))[0];
        $index += 2;
      }
      when 'uint32' {
        %args{$name} = (unpack 'N', $table.subbuf($index, 4))[0];
        $index += 4;
      }
      when 'int32' {
        %args{$name} = (unpack 'N', $table.subbuf($index, 4))[0];
        $index += 4;
      }
      when 'tag' {
        %args{$name} = (unpack 'N', $table.subbuf($index, 4))[0];
        $index += 4;
      }
      when 'uint8-10' {
        %args{$name} = ($table.subbuf($index, 10))[0];
        $index += 4;
      }
      when 'FWORD' {
        %args{$name} = (unpack 'n', $table.subbuf($index, 2))[0];
        $index += 2;
      }
      when 'UFWORD' {
        %args{$name} = (unpack 'n', $table.subbuf($index, 2))[0];
        $index += 2;
      }
      when 'Fixed' {
        my $value = (unpack 'N', $table.subbuf($index, 4))[0];
        %args{$name} = $value / 65536.0;
        $index += 4;
      }
      when 'F2DOT14' {
        my $value = (unpack 'n', $table.subbuf($index, 2))[0];
        %args{$name} = $value / 16384.0;
        $index += 2;
      }
      when 'LONGDATETIME' {
        my ($high, $low) = (unpack 'NN', $table.subbuf($index, 2))[0];
        %args{$name} = ($high +< 32) +| $low;
        $index += 2;
      }
    }
    last if $index >= $length;
  }
  #dd %args;
  %args;
}

class Font::OpenType::Table::Cmap::Encoding {
  has $.platform;
  has $.encoding;
  has $.offset;   # only valid at times during execution of read-table and dump-table
  has $.length          is rw;
  has $.language        is rw;
  has $.glyph-id-array  is rw;
  has $.segcount        is rw;
  has @.end-code        is rw;
  has @.start-code      is rw;
  has @.id-delta        is rw;
  has @.id-range-offset is rw;
  has $.glyph-count     is rw;
}

class Font::OpenType::Table::Cmap {
  has $.version;
  has $.num-tables;
  has @.encoding-record is rw;

  method read-table($table, $length) {
    ($!version, $!num-tables) = unpack 'nn', $table;

    my $index = 4; # skip version and number of records
    for ^$!num-tables {
      my ($platform-id, $encoding-id, $offset) = unpack 'nnN', ($table.subbuf: $index, 8);
      @!encoding-record.push: Font::OpenType::Table::Cmap::Encoding.new(platform => $platform-id,
                                                                        encoding => $encoding-id,
                                                                        offset   => $offset);
      $index += 8;
      #note "Encoding table: $platform-id, $encoding-id, $offset";
    }
    for @!encoding-record -> $encoding-table {
      my $index = $encoding-table.offset;
      my $format = (unpack 'n', $table.subbuf($index, 2))[0];
      given $format {
        when 0 {
          $encoding-table.length   = unpack 'n', $table.subbuf($index, 4);
          $encoding-table.language = unpack 'n', $table.subbuf($index, 6);
          $encoding-table.glyph-id-array = $table.subbuf($index+8, 256);
        }
        when 2 {
          fail "Encoding table format 2 unimplemented";
        }
        when 4 {
          my ($length, $language, $seg-countX2, $search-range, $entry-selector, $range-shift) = unpack 'nnnnnn', $table.subbuf($index+2, 12);
          $encoding-table.segcount = $seg-countX2 / 2;
          my $tindex = $index + 12;
          $encoding-table.end-code  = unpack 'n' xx $encoding-table.segcount, $table.subbuf($tindex, $seg-countX2);
          $tindex += $seg-countX2;
          $tindex += 2;
          $encoding-table.start-code = unpack 'n' xx $encoding-table.segcount, $table.subbuf($tindex, $seg-countX2);
          $tindex += $seg-countX2;
          $encoding-table.id-delta = unpack 'n' xx $encoding-table.segcount, $table.subbuf($tindex, $seg-countX2);
          $tindex += $seg-countX2;
          $encoding-table.id-range-offset = unpack 'n' xx $encoding-table.segcount, $table.subbuf($tindex, $seg-countX2);
          $tindex += $seg-countX2;
          $encoding-table.glyph-count = ($length - $tindex) / 2;
          $encoding-table.glyph-id-array = unpack 'n' xx $encoding-table.glyph-count,
                                                  $table.subbuf($tindex, $encoding-table.glyph-count * 2);
        }
        when 6 {
          fail "Encoding table format 6 unimplemented";
        }
        when 8 {
          fail "Encoding table format 8 unimplemented";
        }
        when 10 {
          fail "Encoding table format 10 unimplemented";
        }
        when 12 {
          fail "Encoding table format 12 unimplemented";
        }
        when 13 {
          fail "Encoding table format 13 unimplemented";
        }
        when 14 {
          fail "Encoding table format 14 unimplemented";
        }
        default {
          fail "Unknown encoding table format $format";
        }
      }
    }
  }
}

class Font::OpenType::Table::Cvt {
  has @.control-value-table;

  method read-table($table, $length) {
    @!control-value-table = unpack('n*', $table);
  }
}

class Font::OpenType::Table::Fpgm {
  has $.program;

  method read-table($table, $length) {
    $!program = $table;
  }
}

class Font::OpenType::Table::Glyf {
  has $.glyphs;

  method read-table($table, $length) {
    $!glyphs = $table;
  }
}

my $loc-format-type;

class Font::OpenType::Table::Head {
    has $.checksum-adjustment;
    has $.magic-number;
    has $.flags;
    has $.units-per-em;
    has $.created;
    has $.modified;
    has $.x-min;
    has $.y-min;
    has $.x-max;
    has $.y-max;
    has $.mac-style;
    has $.lowest-rec-ppem;
    has $.font-direction-hint;
    has $.index-to-loc-format;
    has $.glyph-data-format;

  method read-table(Buf $table, Int $length) {
    my ($major-version, $minor-version) = unpack 'nn', $table;
    fail "Unknown font header table version $major-version.$minor-version"
      unless $major-version == 1 && $minor-version == 0;
    my $font-revision = unpack('N', $table.subbuf(4))[0];
    $font-revision /= 65536.0;
    ($!checksum-adjustment,
     $!magic-number,
     $!flags,
     $!units-per-em,
     $!created,
     $!modified,
     $!x-min,
     $!y-min,
     $!x-max,
     $!y-max,
     $!mac-style,
     $!lowest-rec-ppem,
     $!font-direction-hint,
     $!index-to-loc-format,
     $!glyph-data-format) =
           unpack('NNnnQQnnnnnnnnn', $table.subbuf(8)); # TODO -- fix byte order of dates
    fail "Bad magic number in Font header table" unless $!magic-number == 0x5f0f3cf5;
    $loc-format-type = $!index-to-loc-format;
  }
}
  
class Font::OpenType::Table::Hhea {
  has $.major-version;
  has $.minor-version;
  has $.ascender;
  has $.descender;
  has $.line-gap;
  has $.advance-width-max;
  has $.min-left-side-bearing;
  has $.min-right-side-bearing;
  has $.x-max-extent;
  has $.caret-slope-rise;
  has $.caret-slope-run;
  has $.caret-offset;
  has $.r1;
  has $.r2;
  has $.r3;
  has $.r4;
  has $.metric-date-format;
  has $.number-of-h-metrics;

  my @hhea-table-definition = (
    major-version          => 'uint16',
    minor-version          => 'uint16',
    ascender               => 'FWORD',
    descender              => 'FWORD',
    line-gap               => 'FWORD',
    advance-width-max      => 'UFWORD',
    min-left-side-bearing  => 'FWORD',
    min-right-side-bearing => 'FWORD',
    x-max-extent           => 'FWORD',
    caret-slope-rise       => 'int16',
    caret-slope-run        => 'int16',
    caret-offset           => 'int16',
    r1                     => 'int16',
    r2                     => 'int16',
    r3                     => 'int16',
    r4                     => 'int16',
    metric-date-format     => 'int16',
    number-of-h-metrics    => 'int16',
  );

  method read-table($table, $length) {
    my %args = read-generic-table($table, $length, @hhea-table-definition);
    $number-of-hmetrics = %args<number-of-h-metrics>;
    Font::OpenType::Table::Hhea.new(|%args);
  }
}

class Font::OpenType::Table::Hmtx {
  has $.advanced-width is rw;
  has $.left-side-bearing is rw;

  method read-table($table, $length) {
    my $hmtx = Font::OpenType::Table::Hmtx.new;
    my $index = 0;
    my $i = 0;
    while $i++ < $number-of-hmetrics {
      my ($aw, $lsb) = unpack 'nn', $table.subbuf($index);
      $index += 4;
#      $!advanced-width.push: $aw;
#      $!left-side-bearing.push: $lsb;
    }
    while $i++ < $num-glyphs {
      my $lsb = $table.subbuf($index).unpack: 'n';
      $index += 2;
#      $!left-side-bearing.push: $lsb;
    }
  }
}

class Font::OpenType::Table::Maxp {
  has $.version;
  has $.num-glyphs;
  has $.max-points;
  has $.max-contours;
  has $.max-composite-points;
  has $.max-composite-contours;
  has $.max-zones;
  has $.max-twilight-points;
  has $.max-storage;
  has $.max-function-defs;
  has $.max-instruction-defs;
  has $.max-stack-elements;
  has $.max-size-of-instructions;
  has $.max-component-elements;
  has $.max-component-depth;
  
  my @maxp-table-definition = (
    version                  => 'Fixed',
    num-glyphs               => 'uint16',
    max-points               => 'uint16',
    max-contours             => 'uint16',
    max-composite-points     => 'uint16',
    max-composite-contours   => 'uint16',
    max-zones                => 'uint16',
    max-twilight-points      => 'uint16',
    max-storage              => 'uint16',
    max-function-defs        => 'uint16',
    max-instruction-defs     => 'uint16',
    max-stack-elements       => 'uint16',
    max-size-of-instructions => 'uint16',
    max-component-elements   => 'uint16',
    max-component-depth      => 'uint16',
  );

  method read-table($table, $length) {
    my %args = read-generic-table($table, $length, @maxp-table-definition);
    Font::OpenType::Table::Maxp.new(|%args);
  }
}

class Font::OpenType::Table::Kern::Table {
  has $.n-pairs;
  has $.search-range;
  has $.entry-selector;
  has $.range-shift;
  has @.pairs;
}

class Font::OpenType::Table::Kern {
  has $.version is rw = 0;
  has $.n-tables is rw = 0;
  has $.length;
  has $.coverage;
  has @.tables;

  method read-table($table, $length) {
    ($!version, $!n-tables) = unpack 'nn', $table;
    my $index = 4;
    for ^$!n-tables {
      my $version;
      ($version, $!length, $!coverage) = unpack 'nnn', $table.subbuf(4);
      $index += 6;
      my $format = ($!coverage +> 8) +& 0xff;
      given $format {
        when 0 {
          my ($n-pairs, $search-range, $entry-selector, $range-shift) = unpack 'nnnn', $table.subbuf($index);
          my $subtable = Font::OpenType::Table::Kern::Table.new(:$n-pairs, :$search-range, :$entry-selector, :$range-shift);
          @!tables.push: $subtable;
          $index += 8;
          for ^$n-pairs {
            my ($left, $right, $value) = unpack 'nnn', $table.subbuf($index);
            $index += 6;
            $subtable.pairs.push: %( left => $left, right => $right, value => $value);
          }
        }
        when 2 {
          fail "kern table format 2 unimplemented";
        }
        default {
          fail "Unknown kern subtable format $format";
        }
      }
    }
  }
}

class Font::OpenType::Table::Loca {
  has $.item-length is rw;
  has @.loca;

  method read-table($table, $length) {
    my $index = 0;
    my $format = $loc-format-type ?? 'N' !! 'n';
    $!item-length = $loc-format-type ?? 4 !! 2;
    while $index < $length {
      @!loca.push: unpack $format, $table.subbuf($index, $!item-length);
      $index += $!item-length;
    }
  }
}

class Font::OpenType::Table::Name {
  has $!format;
  has $!count;
  has $!string-offset;
  has @!name-record;
  has $!lang-tag-count;
  has @!lang-tag-record;
  has $.strings;

  method read-table($table, $length) {
    ($!format, $!count, $!string-offset) = unpack 'nnn', $table;

    # read name records
    my $index = 6;
    for ^$!count {
      my ($platform-id, $encoding-id, $language-id, $name-id, $length, $offset) = unpack 'nnnnnn', $table.subbuf($index);
      @!name-record.push: %(
                           platform-id => $platform-id,
                           encoding-id => $encoding-id,
                           language-id => $language-id,
                           name-id     => $name-id,
                           length      => $length,
                           offset      => $offset,
                         );
      $index += 12;
    }

    # read lang tag records
    given $!format {
      when 0 {
      }
      when 1 {
        $!lang-tag-count = (unpack 'n', $table.subbuf($index))[0];
        for ^$!lang-tag-count {
          my ($length, $offset) = unpack 'nn', $table.subbuf($index);
          $index += 4;
          @!lang-tag-record.push: $(length => $length, offset => $offset);
        }
      }
      default {
        fail "Unknown naming table format $!format";
      }
    }
    $!strings = $table.subbuf($index);
  }
}

class Font::OpenType::Table::OS2 {
  has $.version;
  has $.x-avg-char-width;
  has $.us-weight-class;
  has $.us-width-class;
  has $.fs-type;
  has $.y-subscript-x-size;
  has $.y-subscript-y-size;
  has $.y-subscript-x-offset;
  has $.y-subscript-y-offset;
  has $.y-superscript-x-size;
  has $.y-superscript-y-size;
  has $.y-superscript-x-offset;
  has $.y-superscript-y-offset;
  has $.y-strikeout-size;
  has $.y-strikeout-position;
  has $.s-family-class;
  has $.panose;
  has $.ul-unicodee-range1;
  has $.ul-unicodee-range2;
  has $.ul-unicodee-range3;
  has $.ul-unicodee-range4;
  has $.ach-vend-id;
  has $.fs-selection;
  has $.us-first-char-index;
  has $.us-last-char-index;
  has $.s-typo-ascender;
  has $.s-typo-descender;
  has $.s-typo-line-gap;
  has $.us-win-ascent;
  has $.ul-code-page-range1;
  has $.ul-code-page-range2;
  has $.sx-height;
  has $.s-cap-height;
  has $.us-default-char;
  has $.us-break-char;
  has $.us-max-content;
  has $.us-lower-optical-point-size;
  has $.us-upper-optical-point-size;

  my @os2-table-definition = (
    'version'                     => 'uint16',
    'x-avg-char-width'            => 'int16',
    'us-weight-class'             => 'uint16',
    'us-width-class'              => 'uint16',
    'fs-type'                     => 'uint16',
    'y-subscript-x-size'          => 'int16',
    'y-subscript-y-size'          => 'int16',
    'y-subscript-x-offset'        => 'int16',
    'y-subscript-y-offset'        => 'int16',
    'y-superscript-x-size'        => 'int16',
    'y-superscript-y-size'        => 'int16',
    'y-superscript-x-offset'      => 'int16',
    'y-superscript-y-offset'      => 'int16',
    'y-strikeout-size'            => 'int16',
    'y-strikeout-position'        => 'int16',
    's-family-class'              => 'int16',
    'panose'                      => 'uint8-10',
    'ul-unicodee-range1'          => 'uint32',
    'ul-unicodee-range2'          => 'uint32',
    'ul-unicodee-range3'          => 'uint32',
    'ul-unicodee-range4'          => 'uint32',
    'ach-vend-id'                 => 'tag',
    'fs-selection'                => 'uint16',
    'us-first-char-index'         => 'uint16',
    'us-last-char-index'          => 'uint16',
    's-typo-ascender'             => 'int16',
    's-typo-descender'            => 'int16',
    's-typo-line-gap'             => 'int16',
    'us-win-ascent'               => 'uint16',
    'ul-code-page-range1'         => 'uint32',
    'ul-code-page-range2'         => 'uint32',
    'sx-height'                   => 'int16',
    's-cap-height'                => 'int16',
    'us-default-char'             => 'uint16',
    'us-break-char'               => 'uint16',
    'us-max-content'              => 'uint16',
    'us-lower-optical-point-size' => 'uint16',
    'us-upper-optical-point-size' => 'uint16',
  );
  
  method read-table($table, $length) {
#note "Reading table OS/2";
    Font::OpenType::Table::OS2.new(|read-generic-table($table, $length, @os2-table-definition));
  }
}

class Font::OpenType::Table::Post {
  has $.num-glyphs is rw;
  has @.glyph-name-index is rw;
  has @.names is rw;

  my @post-table-definition = (
      version => 'Fixed',
      italic-angle => 'Fixed',
      underline-position => 'FWord',
      underline-thickness => 'FWord',
      is-fixed-pitch      => 'uint32',
      min-mem-type42      => 'uint32',
      max-mem-type42      => 'uint32',
      min-mem-type1       => 'uint32',
      max-mem-type1       => 'uint32',
  );

  method read-table($table, $length) {
    my %args = read-generic-table($table, $length, @post-table-definition);
    given %args<version> {
      when 1.0 {
      }
      when 2.0 {
        $!num-glyphs = unpack 'n', $table.subbuf(28, 2);
        my $index = 30;
        @!glyph-name-index = unpack('n' xx $num-glyphs, $table.subbuf($index));
        @!names            = unpack('n' xx $num-glyphs, $table.subbuf($index + $num-glyphs*2));
      }
      when 2.5 {
        my $index = 30;
        $!num-glyphs = unpack 'n', $table.subbug(28, 2);
        @!glyph-name-index = unpack 'n' xx $num-glyphs, $table.subbuf($index);
      }
      when 3.0 {
      }
      default {
        fail "Unknown Postscript Table format $_";
      }
    }
  }
}

class Font::OpenType::Table::Prep {
  has $.program;

  method read-table($table, $length) {
    $!program = $table;
  }
}

class Font::OpenType {
  has %.table;

  my %table = ();

  our sub read-file($filename) {
    my $fh = $filename.IO.open: :bin or die "Could not open file";
    my $type = $fh.read: 4;
    given $type {
      when Buf.new(0,1,0,0) {
        read-ttf-file($fh);
      }
      when Buf.new(0x4f, 0x54, 0x54, 0x4f) {
        read-ttc-file($fh);
      }
      default {
        die "Unknown file format";
      }
    }
  }

  sub read-ttf-file($fh) {
    my $otf = Font::OpenType.new();

    $fh.seek: 4; # skip file type
    my $buf = $fh.read: 8;
    my ($num-tables, $search-range, $entry-selector, $range-shift) = unpack('nnnn', $buf);

    # read table record entries
    for ^$num-tables {
      $buf = $fh.read: 16;
      my ($table-tag, $check-sum, $offset, $length) = unpack('a4NNN', $buf);
      #note "Table: $table-tag, $check-sum, $offset, $length";
      %table{$table-tag} = %(check-sum => $check-sum, offset => $offset, length => $length, read => 0);
    }

    # Read tables
    for %table.keys.sort -> $tag { # sort for debugging; probably unnecessary in production code, but helps with repeatablility
      $otf.read-table: $fh, $tag;
    }
    $otf;
  }

  sub check-checksum(Buf $buf, $checksum) {
    True; # TODO
  }

  sub read-ttc-file($fh) {
  }

  method read-table($fh, $tag) {
    my $props = %table{$tag};
    return if $props<read>; # We've already been here
    $props<read> = 1; # optimism!
    my $length = $props<length>;
    $fh.seek: $props<offset>;
    my $buf = $fh.read: $length;
    check-checksum($buf, $props<check-sum>);

note "reading table $tag";
    given $tag {
      when 'OS/2' {
        %!table<OS/2> = Font::OpenType::Table::OS2.new();
        %!table<OS/2>.read-table($buf, $length);
      }
      when 'cmap' {
        %!table<cmap> = Font::OpenType::Table::Cmap.new;
        %!table<cmap>.read-table($buf, $length);
      }
      when 'cvt ' {
        %!table<cvt> = Font::OpenType::Table::Cvt.new();
        %!table<cvt>.read-table($buf, $length);
      }
      when 'fpgm' {
        %!table<fpgm> = Font::OpenType::Table::Fpgm.new();
        %!table<fpgm>.read-table($buf, $length);
      }
      when 'glyf' {
        %!table<glyf> = Font::OpenType::Table::Glyf.new();
        %!table<glyf>.read-table($buf, $length);
      }
      when 'head' {
        %!table<head> = Font::OpenType::Table::Head.new();
        %!table<head>.read-table($buf, $length);
      }
      when 'hhea' {
        %!table<hhea> = Font::OpenType::Table::Hhea.new();
        %!table<hhea>.read-table($buf, $length);
      }
      when 'hmtx' {
        %!table<hhea> = self.read-table($fh, 'hhea') unless %!table<hhea>.defined; # needed for number-of-hmetrics
        %!table<maxp> = self.read-table($fh, 'maxp') unless %!table<maxp>.defined; # needed for num-glyphs
        %!table<hmtx> = Font::OpenType::Table::Hmtx.new{};
        %!table<hmtx>.read-table($buf, $length);
      }
      when 'kern' {
        %!table<kern> = Font::OpenType::Table::Kern.new();
        %!table<kern>.read-table($buf, $length);
      }
      when 'loca' {
        %!table<loca> = Font::OpenType::Table::Loca.new();
        %!table<loca>.read-table($buf, $length);
      }
      when 'maxp' {
        %!table<maxp> = Font::OpenType::Table::Maxp.new();
        %!table<maxp>.read-table($buf, $length);
      }
      when 'name' {
        %!table<name> = Font::OpenType::Table::Name.new();
        %!table<name>.read-table($buf, $length);
      }
      when 'post' {
	%!table<post> = Font::OpenType::Table::Post.new;
	%!table<post>.read-table($buf, $length);
      }
      when 'prep' {
	%!table<prep> = Font::OpenType::Table::Prep.new;
	%!table<prep>.read-table($buf, $length);
      }
      default {
        fail "Unknown or unimplemented table type $tag";
      }
    }
  }

} # class Font::OpenType

my $filename = '/home/kevinp/Fonts/Univers/UniversBlack.ttf';

my $font = Font::OpenType::read-file($filename);
#dd $font;
for $font.table.keys.sort:{$^a.fc leg $^b.fc} -> $tag {
  say $tag;
}
dd $font.table<hmtx>;
