#!/usr/bin/env perl6
#unit module Font::OpenType;

use v6;

use P5pack;

sub read-file($filename) {
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
note "Reading TTF format";
  $fh.seek: 4; # skip file type
  my $buf = $fh.read: 8;
  my ($num-tables, $search-range, $entry-selector, $range-shift) = unpack('nnnn', $buf);
note "$num-tables, $search-range, $entry-selector, $range-shift";

  for ^$num-tables {
    $buf = $fh.read: 16;
    my ($table-tag, $check-sum, $offset, $length) = unpack('a4NNN', $buf);
    note "Table: $table-tag, $check-sum, $offset, $length";
    my $pos = $fh.tell;
    $fh.seek: $offset;
    my $table = $fh.read: $length;
    check-checksum($table, $check-sum);
    read-table($table, $table-tag, $length);
    $fh.seek: $pos;
  }
}

sub check-checksum(Buf $buf, $checksum) {
  True; # TODO
}

sub read-ttc-file($fh) {
}

sub read-table(Buf $buf, $tag, $length) {
  given $tag {
    when 'OS/2' {
      read-os2($buf, $length);
    }
    when 'cmap' {
      read-cmap($buf, $length);
    }
    when 'cvt ' {
      read-cvt($buf, $length);
    }
    when 'fpgm' {
      read-fpgm($buf, $length);
    }
    when 'glyf' {
      read-glyf($buf, $length);
    }
    when 'head' {
      read-head($buf, $length);
    }
    when 'hhea' {
      read-hhea($buf, $length);
    }
    when 'hmtx' {
# TODO -- when I can understand the table format
    }
    when 'kern' {
      read-kern($buf, $length);
    }
    when 'loca' {
      read-loca($buf, $length);
    }
    when 'maxp' {
      read-maxp($buf, $length);
    }
    when 'name' {
      read-name($buf, $length);
    }
    when 'post' {
    }
    when 'prep' {
    }
    default {
      fail "Unknown or unimplemented table type $tag";
    }
  }
}

my @os2-table-definition = (
  'version'                 => 'uint16',
  'xAvgCharWidth'           => 'int16',
  'usWeightClass'           => 'uint16',
  'usWidthClass'            => 'uint16',
  'fsType'                  => 'uint16',
  'ySubscriptXSize'         => 'int16',
  'ySubscriptYSize'         => 'int16',
  'ySubscriptXOffset'       => 'int16',
  'ySubscriptYOffset'       => 'int16',
  'ySuperscriptXSize'       => 'int16',
  'ySuperscriptYSize'       => 'int16',
  'ySuperscriptXOffset'     => 'int16',
  'ySuperscriptYOffset'     => 'int16',
  'yStrikeoutSize'          => 'int16',
  'yStrikeoutPosition'      => 'int16',
  'sFamilyClass'            => 'int16',
  'panose'                  => 'uint8-10',
  'ulUnicodeeRange1'        => 'uint32',
  'ulUnicodeeRange2'        => 'uint32',
  'ulUnicodeeRange3'        => 'uint32',
  'ulUnicodeeRange4'        => 'uint32',
  'achVendID'               => 'tag',
  'fsSelection'             => 'uint16',
  'usFirstCharIndex'        => 'uint16',
  'usLastCharIndex'         => 'uint16',
  'sTypoAscender'           => 'int16',
  'sTypoDescender'          => 'int16',
  'sTypoLineGap'            => 'int16',
  'usWinAscent'             => 'uint16',
  'ulCodePageRange1'        => 'uint32',
  'ulCodePageRange2'        => 'uint32',
  'sxHeight'                => 'int16',
  'sCapHeight'              => 'int16',
  'usDefaultChar'           => 'uint16',
  'usBreakChar'             => 'uint16',
  'usMaxContent'            => 'uint16',
  'usLowerOpticalPointSize' => 'uint16',
  'usUpperOpticalPointSize' => 'uint16',
);

sub read-os2($table, $length) {
  read-generic-table($table, $length, @os2-table-definition);
}

sub read-generic-table($table, $length, @table-definition) {
  my $index = 0;
  my %args;
  for @table-definition -> $pair {
    my ($name, $type) = $pair.kv;
note "Looking for $type for $name";
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
  dd %args;
  %args;
}

sub read-cmap($table, $length) {
  my ($version, $num-tables) = unpack 'nn', $table;

  my @encoding-records;

  my @tables;
  my $index = 4; # skip version and number of records
  for ^$num-tables {
    my ($platform-id, $encoding-id, $offset) = unpack 'nnN', ($table.subbuf: $index, 8);
    @tables.push: %(platform => $platform-id, encoding => $encoding-id, offset => $offset);
    $index += 8;
    note "Encoding table: $platform-id, $encoding-id, $offset";
  }
  for @tables -> $encoding-table {
    my $index = $encoding-table<offset>;
    my $format = (unpack 'n', $table.subbuf($index, 2))[0];
    given $format {
      when 0 {
note "Encoding table format 0";
        my $length   = unpack 'n', $table.subbuf($index, 4);
        my $language = unpack 'n', $table.subbuf($index, 6);
        my $glyph-id-array = $table.subbuf($index+8, 256);
      }
      when 2 {
        fail "Encoding table format 2 unimplemented";
      }
      when 4 {
        my ($length, $language, $seg-countX2, $search-range, $entry-selector, $range-shift) = unpack 'nnnnnn', $table.subbuf($index+2, 12);
        my $segcount = $seg-countX2 / 2;
        my $tindex = $index + 12;
        my @end-code  = unpack 'n' xx $segcount, $table.subbuf($tindex, $seg-countX2);
        $tindex += $seg-countX2;
        $tindex += 2;
        my @start-code = unpack 'n' xx $segcount, $table.subbuf($tindex, $seg-countX2);
        $tindex += $seg-countX2;
        my @id-delta = unpack 'n' xx $segcount, $table.subbuf($tindex, $seg-countX2);
        $tindex += $seg-countX2;
        my @id-rabge-offset = unpack 'n' xx $segcount, $table.subbuf($tindex, $seg-countX2);
        $tindex += $seg-countX2;
        my $glyph-count = ($length - $tindex) / 2;
        my @glyph-id-array = unpack 'n' xx $glyph-count, $table.subbuf($tindex, $glyph-count * 2);
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

sub read-cvt($table, $length) {
  my $count = $length / 2;
  my $format = "n$count";
  my @control-value-table = unpack $format, $table;
}

sub read-fpgm($table, $length) {
  my $program = $table;
}

sub read-glyf($table, $length) {
  my $glyphs = $table;
}

my $loc-format-type;

sub read-head(Buf $table, Int $length) {
  my ($major-version, $minor-version) = unpack 'nn', $table;
  fail "Unknown font header tabole version $major-version.$minor-version"
    unless $major-version == 1 && $minor-version == 0;
  my $font-revision = unpack('N', $table.subbuf(4))[0];
  $font-revision /= 65536.0;
  my ($checksum-adjustment,
      $magic-number,
      $flags,
      $units-per-em,
      $created,
      $modified,
      $x-min,
      $y-min,
      $x-max,
      $y-max,
      $mac-style,
      $lowest-rec-ppem,
      $font-direction-hint,
      $index-to-loc-format,
      $glyph-data-format) =
         unpack('NNnnQQnnnnnnnnn', $table.subbuf(8)); # TODO -- fix byte order of dates
  fail "Bad magic number in Font header table" unless $magic-number == 0x5f0f3cf5;
  $loc-format-type = $index-to-loc-format;
}

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

sub read-hhea($table, $length) {
  read-generic-table($table, $length, @hhea-table-definition);
}

sub read-kern($table, $length) {
  my ($version, $n-tables) = unpack 'nn', $table;
  my $index = 4;
  for ^$n-tables {
    my ($version, $length, $coverage) = unpack 'nnn', $table.subbuf(4);
    $index += 6;
    my $format = ($coverage +> 8) +& 0xff;
    my @kern;
    given $format {
      when 0 {
        my ($n-pairs, $search-range, $entry-selector, $range-shift) = unpack 'nnnn', $table.subbuf($index);
        $index += 8;
        for ^$n-pairs {
          my ($left, $right, $value) = unpack 'nnn', $table.subbuf($index);
          $index += 6;
          @kern.push: %( left => $left, right => $right, value => $value);
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

sub read-loca($table, $length) {
  my @loca;
  my $index = 0;
  my $format = $loc-format-type ?? 'N' !! 'n';
  my $item-length = $loc-format-type ?? 4 !! 2;
  while $index < $length {
    @loca.push: unpack $format, $table.subbuf($index, $item-length);
    $index += $item-length;
  }
}

my @maxp-table-definition= (
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

sub read-maxp($table, $length) {
  my %args = read-generic-table($table, $length, @maxp-table-definition);
}

sub read-name($table, $length) {
  my ($format, $count, $string-offset) = unpack 'nnn', $table;

# read name records
  my $index = 6;
  my @name-record;
  for ^$count {
    my ($platform-id, $encoding-id, $language-id, $name-id, $length, $offset) = unpack 'nnnnnn', $table.subbuf($index);
    @name-record.push: %(
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
  my @lang-tag-record;
  given $format {
    when 0 {
    }
    when 1 {
      my $lang-tag-count = (unpack 'n', $table.subbuf($index))[0];
      for ^$lang-tag-count {
        my ($length, $offset) = unpack 'nn', $table.subbuf($index);
        $index += 4;
        @lang-tag-record.push: $(length => $length, offset => $offset);
      }
    }
    default {
      fail "Unknown naming table format $format";
    }
  }
  dd @lang-tag-record;
  my $strings = $table.subbuf($index);
}

my $filename = '/home/kevinp/Fonts/Univers/UniversBlack.ttf';

read-file($filename);
