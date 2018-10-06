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
    }
    when 'fpgm' {
    }
    when 'glyf' {
    }
    when 'head' {
    }
    when 'hhea' {
    }
    when 'hmtx' {
    }
    when 'kern' {
    }
    when 'loca' {
    }
    when 'maxp' {
    }
    when 'name' {
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

sub read-generic-table($table, $length, $table-definition) {
  my $index = 0;
  my %args;
  for $table-definition -> $pair {
    my ($name, $type) = $pair.kv;
    given $type {
      when 'uint16' {
        (%args{$name}) = unpack 'n', $table.subbuf($index, 2);
        $index += 2;
      }
      when 'int16' {
        (%args{$name}) = unpack 'n', $table.subbuf($index, 2);
        $index += 2;
      }
      when 'uint32' {
        (%args{$name}) = unpack 'N', $table.subbuf($index, 4);
        $index += 4;
      }
      when 'int32' {
        (%args{$name}) = unpack 'N', $table.subbuf($index, 4);
        $index += 4;
      }
      when 'tag' {
        (%args{$name}) = unpack 'N', $table.subbuf($index, 4);
        $index += 4;
      }
      when 'uint8-10' {
        (%args{$name}) = $table.subbuf($index, 10);
        $index += 4;
      }
    }
    last if $index >= $length;
  }
}

sub read-cmap($table, $length) {
  my ($version, $num-tables) = unpack 'nn', $table;

  my @encoding-records;

  my $index = 4; # skip version and number of records
  for ^$num-tables {
    my ($platform-id, $encoding-id, $offset) = unpack 'nnN', ($table.subbuf: $index, 8);
    $index += 8;
    note "Encoding table: $platform-id, $encoding-id, $offset";
  }
}

my $filename = '/home/kevinp/Fonts/Univers/UniversBlack.ttf';

read-file($filename);
