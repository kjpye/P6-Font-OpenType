#!/usr/bin/env perl6

use v6;

use P5pack;

my $num-glyphs = -1;
my $number-of-hmetrics = -1;

sub read-generic-table($object, $table, $length, @table-definition) {
  my $index = 0;
  for @table-definition -> $pair {
    my ($name, $type) = $pair.kv;
    given $type {
      when 'uint16' {
        $object."$name"() = (unpack 'n', $table.subbuf($index, 2))[0];
        $index += 2;
      }
      when 'int16' {
        $object."$name"() = (unpack 'n', $table.subbuf($index, 2))[0];
        $index += 2;
      }
      when 'uint32' {
        $object."$name"() = (unpack 'N', $table.subbuf($index, 4))[0];
        $index += 4;
      }
      when 'int32' {
        $object."$name"() = (unpack 'N', $table.subbuf($index, 4))[0];
        $index += 4;
      }
      when 'tag' {
        $object."$name"() = (unpack 'N', $table.subbuf($index, 4))[0];
        $index += 4;
      }
      when 'uint8-10' {
        $object."$name"() = ($table.subbuf($index, 10))[0];
        $index += 4;
      }
      when 'FWORD' {
        $object."$name"() = (unpack 'n', $table.subbuf($index, 2))[0];
        $index += 2;
      }
      when 'UFWORD' {
        $object."$name"() = (unpack 'n', $table.subbuf($index, 2))[0];
        $index += 2;
      }
      when 'Fixed' {
        my $value = (unpack 'N', $table.subbuf($index, 4))[0];
        $object."$name"() = $value / 65536.0;
        $index += 4;
      }
      when 'F2DOT14' {
        my $value = (unpack 'n', $table.subbuf($index, 2))[0];
        $object."$name"() = $value / 16384.0;
        $index += 2;
      }
      when 'LONGDATETIME' {
        my ($high, $low) = (unpack 'NN', $table.subbuf($index, 2))[0];
        $object."$name"() = ($high +< 32) +| $low;
        $index += 2;
      }
    }
    last if $index >= $length;
  }
}

sub write-generic-table($object, @table-definition) {
  my $buf = buf8.new();;
  for @table-definition -> $pair {
    my ($name, $type) = $pair.kv;
    given $type {
      when 'uint16' {
        $buf ~= pack 'n', $object."$name"();
      }
      when 'int16' {
        $buf ~= pack 'n', $object."$name"();
      }
      when 'uint32' {
        $buf ~= pack 'N', $object."$name"();
      }
      when 'int32' {
        $buf ~= pack 'N', $object."$name"();
      }
      when 'tag' {
        $buf ~= pack 'N', $object."$name"();
      }
      when 'uint8-10' {
        $buf ~= $object."$name"();
      }
      when 'FWORD' {
        $buf ~= pack 'n', $object."$name"();
      }
      when 'UFWORD' {
        $buf ~= pack 'n', $object."$name"();
      }
      when 'Fixed' {
        $buf ~= pack 'N', ($object."$name"() * 65536).int;
      }
      when 'F2DOT14' {
        $buf ~= pack 'n', ($object."$name"() * 16384).int;
      }
      when 'LONGDATETIME' {
        $buf ~= pack 'NN', $object."$name"() +> 32, $object."$name"();
      }
    }
  }
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
  has @.glyphs;

  method read-table($table, $length, $loca) {
    my $count = $loca.elems;
    for ^$count -> $i {
      my $length = $i < $count - 1 ?? $loca[$i+1] - $loca[$i] !! $table.elems - $loca[$i];
      @!glyphs[$i] = $table.subbuf($loca[$i], $length);
    }
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
  has $.major-version          is rw;
  has $.minor-version          is rw;
  has $.ascender               is rw;
  has $.descender              is rw;
  has $.line-gap               is rw;
  has $.advance-width-max      is rw;
  has $.min-left-side-bearing  is rw;
  has $.min-right-side-bearing is rw;
  has $.x-max-extent           is rw;
  has $.caret-slope-rise       is rw;
  has $.caret-slope-run        is rw;
  has $.caret-offset           is rw;
  has $.r1                     is rw;
  has $.r2                     is rw;
  has $.r3                     is rw;
  has $.r4                     is rw;
  has $.metric-date-format     is rw;
  has $.number-of-h-metrics    is rw;

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
    read-generic-table(self, $table, $length, @hhea-table-definition);
    $number-of-hmetrics = $!number-of-h-metrics;
  }
}

class Font::OpenType::Table::Hmtx {
  has $.advanced-width is rw;
  has $.left-side-bearing is rw;

  method read-table($table, $length, $number-of-h-metrics, $num-glyphs) {
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
  has $.version                  is rw;
  has $.num-glyphs               is rw;
  has $.max-points               is rw;
  has $.max-contours             is rw;
  has $.max-composite-points     is rw;
  has $.max-composite-contours   is rw;
  has $.max-zones                is rw;
  has $.max-twilight-points      is rw;
  has $.max-storage              is rw;
  has $.max-function-defs        is rw;
  has $.max-instruction-defs     is rw;
  has $.max-stack-elements       is rw;
  has $.max-size-of-instructions is rw;
  has $.max-component-elements   is rw;
  has $.max-component-depth      is rw;
  
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
    read-generic-table(self, $table, $length, @maxp-table-definition);
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

  method read-table($table, $length, $loc-format-type) {
    my $index = 0;
    my $format = $loc-format-type ?? 'N' !! 'n';
    $!item-length = $loc-format-type ?? 4 !! 2;
    while $index < $length {
      @!loca.push: (unpack $format, $table.subbuf($index, $!item-length))[0];
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
  has $.version                     is rw;
  has $.x-avg-char-width            is rw;
  has $.us-weight-class             is rw;
  has $.us-width-class              is rw;
  has $.fs-type                     is rw;
  has $.y-subscript-x-size          is rw;
  has $.y-subscript-y-size          is rw;
  has $.y-subscript-x-offset        is rw;
  has $.y-subscript-y-offset        is rw;
  has $.y-superscript-x-size        is rw;
  has $.y-superscript-y-size        is rw;
  has $.y-superscript-x-offset      is rw;
  has $.y-superscript-y-offset      is rw;
  has $.y-strikeout-size            is rw;
  has $.y-strikeout-position        is rw;
  has $.s-family-class              is rw;
  has $.panose                      is rw;
  has $.ul-unicodee-range1          is rw;
  has $.ul-unicodee-range2          is rw;
  has $.ul-unicodee-range3          is rw;
  has $.ul-unicodee-range4          is rw;
  has $.ach-vend-id                 is rw;
  has $.fs-selection                is rw;
  has $.us-first-char-index         is rw;
  has $.us-last-char-index          is rw;
  has $.s-typo-ascender             is rw;
  has $.s-typo-descender            is rw;
  has $.s-typo-line-gap             is rw;
  has $.us-win-ascent               is rw;
  has $.ul-code-page-range1         is rw;
  has $.ul-code-page-range2         is rw;
  has $.sx-height                   is rw;
  has $.s-cap-height                is rw;
  has $.us-default-char             is rw;
  has $.us-break-char               is rw;
  has $.us-max-content              is rw;
  has $.us-lower-optical-point-size is rw;
  has $.us-upper-optical-point-size is rw;

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
    read-generic-table(self, $table, $length, @os2-table-definition);
  }
}

class Font::OpenType::Table::Post {
  has $.num-glyphs          is rw;
  has @.glyph-name-index    is rw;
  has @.names               is rw;
  has $.version             is rw;
  has $.italic-angle        is rw;
  has $.underline-position  is rw;
  has $.underline-thickness is rw;
  has $.is-fixed-pitch      is rw;
  has $.min-mem-type42      is rw;
  has $.max-mem-type42      is rw;
  has $.min-mem-type1       is rw;
  has $.max-mem-type1       is rw;

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
    read-generic-table(self, $table, $length, @post-table-definition);
    given $!version {
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

    given $tag {
      unless %!table{$tag}.defined {
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
          self.read-table($fh, 'loca') unless %!table<loca>.defined;
          %!table<glyf> = Font::OpenType::Table::Glyf.new();
          %!table<glyf>.read-table($buf, $length, %!table<loca>.loca);
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
          self.read-table($fh, 'hhea') unless %!table<hhea>.defined; # needed for number-of-h-metrics
          self.read-table($fh, 'maxp') unless %!table<maxp>.defined; # needed for num-glyphs
          %!table<hmtx> = Font::OpenType::Table::Hmtx.new{};
          %!table<hmtx>.read-table($buf, $length, %!table<hhea>.number-of-h-metrics, %!table<maxp>.num-glyphs);
        }
        when 'kern' {
          %!table<kern> = Font::OpenType::Table::Kern.new();
          %!table<kern>.read-table($buf, $length);
        }
        when 'loca' {
          self.read-table($fh, 'head') unless %!table<head>.defined; # needed for index-to-loc-format
          %!table<loca> = Font::OpenType::Table::Loca.new();
          %!table<loca>.read-table($buf, $length, %!table<head>.index-to-loc-format);
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
  }

  method write-file() {
  }

} # class Font::OpenType

my $filename = '/home/kevinp/Fonts/Univers/UniversBlack.ttf';

my $font = Font::OpenType::read-file($filename);
