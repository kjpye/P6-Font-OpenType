#!/usr/bin/env perl6

use v6.d+;

use P5pack;

my $num-glyphs = -1;
my $number-of-hmetrics = -1;

sub read-generic-table($object, $table, $length, @table-definition) {
  my $index = 0;
  for @table-definition -> $pair {
    my ($name, $type) = $pair.kv;
    given $type {
      when 'uint16' {
        $object."$name"() = $table.read-uint16($index, BigEndian);
        $index += 2;
      }
      when 'int16' {
        $object."$name"() = $table.read-int16($index, BigEndian);
        $index += 2;
      }
      when 'uint32' {
        $object."$name"() = $table.read-uint32($index, BigEndian);
        $index += 4;
      }
      when 'int32' {
        $object."$name"() = $table.read-int32($index, BigEndian);
        $index += 4;
      }
      when 'tag' {
        $object."$name"() = $table.read-uint32($index, BigEndian);
        $index += 4;
      }
      when 'uint8-10' {
        $object."$name"() = ($table.subbuf($index, 10))[0];
        $index += 4;
      }
      when 'FWORD' {
        $object."$name"() = $table.read-int16($index, BigEndian);
        $index += 2;
      }
      when 'UFWORD' {
        $object."$name"() = $table.read-uint16($index, BigEndian);
        $index += 2;
      }
      when 'Fixed' {
        my $value = $table.read-uint32($index, BigEndian);
        $object."$name"() = $value / 65536.0;
        $index += 4;
      }
      when 'F2DOT14' {
        my $value = $table.read-uint16($index, BigEndian);
        $object."$name"() = $value / 16384.0;
        $index += 2;
      }
      when 'LONGDATETIME' {
        $object."$name"() = $table.read-uint64($index, BigEndian);
        $index += 8;
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

sub read-uint16-array($buf, $offset is copy, $count) {
  my @array;
  for ^$count {
    @array.push: $buf.read-uint16($offset, BigEndian);
    $offset += 2;
  }
  @array;
}

class Font::OpenType::Table::Cmap {
  has $.version;
  has $.num-tables;
  has @.encoding-record is rw;

  method read-table($table, $length) {
    $!version    = $table.read-uint16(0, BigEndian);
    $!num-tables = $table.read-uint16(2, BigEndian);

    my $index = 4; # skip version and number of records
    for ^$!num-tables {
      my $platform-id = $table.read-uint16($index, BigEndian); $index += 2;
      my $encoding-id = $table.read-uint16($index, BigEndian); $index += 2;
      my $offset      = $table.read-uint32($index, BigEndian); $index += 4;
      @!encoding-record.push: Font::OpenType::Table::Cmap::Encoding.new(platform => $platform-id,
                                                                        encoding => $encoding-id,
                                                                        offset   => $offset);
    }
    for @!encoding-record -> $encoding-table {
      my $index = $encoding-table.offset;
      my $format = $table.read-uint16($index, BigEndian); $index += 2;
      given $format {
        when 0 {
          $encoding-table.length   = $table.read-uint16($index, BigEndian); $index += 2;
          $encoding-table.language = $table.read-uint16($index, BigEndian); $index += 2;
          $encoding-table.glyph-id-array = $table.subbuf($index, 256);
        }
        when 2 {
          fail "Encoding table format 2 unimplemented";
        }
        when 4 {
          my $length         = $table.read-uint16($index, BigEndian); $index += 2;
          my $language       = $table.read-uint16($index, BigEndian); $index += 2;
          my $seg-countX2    = $table.read-uint16($index, BigEndian); $index += 2;
          my $search-range   = $table.read-uint16($index, BigEndian); $index += 2;
          my $entry-selector = $table.read-uint16($index, BigEndian); $index += 2;
          my $range-shift    = $table.read-uint16($index, BigEndian); $index += 2;
          $encoding-table.segcount = $seg-countX2 / 2;
          $encoding-table.end-code        = read-uint16-array($table, $index, $encoding-table.segcount);
          $index += $seg-countX2;
          $encoding-table.start-code      = read-uint16-array($table, $index, $encoding-table.segcount);
          $index += $seg-countX2;
          $encoding-table.id-delta        = read-uint16-array($table, $index, $encoding-table.segcount);
          $index += $seg-countX2;
          $encoding-table.id-range-offset = read-uint16-array($table, $index, $encoding-table.segcount);
          $index += $seg-countX2;
          $encoding-table.glyph-count = ($length - $index + $encoding-table.offset) / 2;
          $encoding-table.glyph-id-array  = read-uint16-array($table, $index, $encoding-table.glyph-count);
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
    @!control-value-table = read-uint16-array($table, 0, $table.elems / 2);
  }
}

class Font::OpenType::Table::Fpgm {
  has $.program;

  method read-table($table, $length) {
    $!program = $table;
  }
}

class Font::OpenType::Glyf {
  has $.number-of-contours is rw;
  has $.x-min is rw;
  has $.x-max is rw;
  has $.y-min is rw;
  has $.y-max is rw;
  has @.end-pts-of-contours is rw;
  has $.instruction-length is rw;
  has $.instructions is rw;
  has @.flags is rw;
  has @.x-coordinates is rw;
  has @.y-coordinates is rw;

  our sub read-glyf($buf) {
    my $glyf    = Font::OpenType::Glyf.new();
    my $numcont = $buf.read-uint16(0, BigEndian);
    my $xmin    = $buf.read-uint16(2, BigEndian);
    my $ymin    = $buf.read-uint16(4, BigEndian);
    my $xmax    = $buf.read-uint16(6, BigEndian);
    my $ymax    = $buf.read-uint16(8, BigEndian);
    $glyf.number-of-contours = $numcont;
    $glyf.x-min = $xmin;
    $glyf.y-min = $ymin;
    $glyf.x-max = $xmax;
    $glyf.y-max = $ymax;
    if $numcont < 0 {
      fail "Composite glyphs not implemented";
    }
    $glyf.end-pts-of-contours = read-uint16-array($buf, 10, $glyf.number-of-contours);
    my $index = $glyf.number-of-contours * 2 + 10;
    $glyf.instruction-length = $buf.read-uint16($index, BigEndian);
    $index += 2;
    $glyf.instructions = $buf.subbuf($index, $glyf.instruction-length);
    $index += $glyf.instruction-length;
  # read flags -- complicated by flag compression
    my $num-flags = $glyf.number-of-contours;
    while $num-flags > 0 {
      my $flag = $buf.read-uint8($index++);
      $glyf.flags.push: $flag;
      $num-flags--;
      if $flag +& 0x08 { # repeat bit
        my $repeat-count = $buf.read-uint8($index++);
        $glyf.flags.append: $flag x $repeat-count;
        $num-flags -= $repeat-count;
      }
    }
  # read X coordinates -- even more complicated
    my $oldvalue = 0;
    for $glyf.flags -> $flag {
      my $value;
      if $flag +& 0x02 { # X_SHORT_VECTOR
        $value = $buf.read-int8($index++);
        if $flag +& 0x10 {
          $value = -$value;
        }
      } else {
        if $flag +& 0x10 {
          $value = $oldvalue;
        } else {
          $value = $buf.read-uint16($index, BigEndian);
        }
      }
      $glyf.x-coordinates.push: $value;
      $oldvalue = $value;
    }
  # read Y coordinates -- same as X coordinates
    $oldvalue = 0;
    for $glyf.flags -> $flag {
      my $value;
      if $flag +& 0x04 { # Y_SHORT_VECTOR
        $value = $buf.read-int8($index++);
        if $flag +& 0x20 {
          $value = -$value;
        }
      } else {
        if $flag +& 0x20 {
          $value = $oldvalue;
        } else {
          $value = $buf.read-uint16($index, BigEndian);
        }
      }
      $glyf.y-coordinates.push: $value;
      $oldvalue = $value;
    }
    $glyf;
  }
 
  sub push-bytes($count is copy, $program, $index is rw) {
    print "pushb[{$count - 1}] ";
    while --$count {
      print $program[++$index];
      print ',' if $count;
    }
    print "\n";
  }

  sub push-words($count is copy, $program, $index is rw) {
    print "pushw[{$count - 1}] ";
    while --$count {
      my $word = $program[++$index] +< 8;
      $word  +|= $program[++$index];
      print $word,
      print ',' if $count;
    }
    print "\n";
  }

  method dump() {
    my $index = 0;
    while $index < $!instructions.elems {
      given $!instructions[$index] {
        when 0x00 .. 0x01 {
          say "svtca[{$_ - 0x00}]";
        }
        when 0x02 .. 0x03 {
          say "spvtca[{$_ - 0x02}]";
        }
        when 0x04 .. 0x05 {
          say "sfvtca[{$_ - 0x04}]";
        }
        when 0x06 .. 0x07 {
          say "spvtl[{$_ - 0x06}]";
        }
        when 0x08 .. 0x09 {
          say "sfvtl[{$_ - 0x08}]";
        }
        when 0x0a {
          say "spvfs";
        }
        when 0x0b {
          say "sfvfs";
        }
        when 0x0c {
          say "gpv";
        }
        when 0x0d {
          say "gfv";
        }
        when 0x0e {
          say "sfvtpv";
        }
        when 0x0f {
          say "isect";
        }
        when 0x10 {
          say "srp0";
        }
        when 0x11 {
          say "srp1";
        }
        when 0x12 {
          say "srp2";
        }
        when 0x13 {
          say "szp0";
        }
        when 0x14 {
          say "szp1";
        }
        when 0x15 {
          say "szp2";
        }
        when 0x16 {
          say "szps";
        }
        when 0x17 {
          say "sloop";
        }
        when 0x18 {
          say "rtg";
        }
        when 0x19 {
          say "rthg";
        }
        when 0x1a {
          say "smd";
        }
        when 0x1b {
          say "else";
        }
        when 0x1c {
          say "jmpr";
        }
        when 0x1d {
          say "scvtci";
        }
        when 0x1e {
          say "sswci";
        }
        when 0x1f {
          say "ssw";
        }
        when 0x20 {
          say "dup";
        }
        when 0x21 {
          say "pop";
        }
        when 0x22 {
          say "clear";
        }
        when 0x23 {
          say "swap";
        }
        when 0x24 {
          say "depth";
        }
        when 0x25 {
          say "cindex";
        }
        when 0x26 {
          say "mindex";
        }
        when 0x27 {
          say "alignpts";
        }
        when 0x29 {
          say "utp";
        }
        when 0x2a {
          say "loopcall";
        }
        when 0x2b {
          say "call";
        }
        when 0x2c {
          say "fdef";
        }
        when 0x2d {
          say "endf";
        }
        when 0x2e .. 0x2f {
          say "mdap[{$_ - 0x2e}]";
        }
        when 0x30 .. 0x31 {
          say "iup[{$_ - 0x30}]";
        }
        when 0x34 .. 0x35 {
          say "shc[{$_ - 0x33}]";
        }
        when 0x32 .. 0x33 {
          say "shp[{$_ - 0x32}]";
        }
        when 0x36 .. 0x37 {
          say "shz[{$_ - 0x36}]";
        }
        when 0x38 {
          say "shpix";
        }
        when 0x39 {
          say "ip";
        }
        when 0x3a .. 0x3b {
          say "msirp[{$_ - 0x3a}]";
        }
        when 0x3c {
          say "alignrp";
        }
        when 0x3d {
          say "rtdg";
        }
        when 0x3e .. 0x3f {
          say "miap[{$_ - 0x3e}]";
        }
        when 0x40 {
          my $count = $!instructions[++$index];
          print "npushb $count";
          while $count-- {
            my $byte = $!instructions[++$index];
            print ",$byte";
          }
          say '';
        }
        when 0x41 {
          my $count = $!instructions[++$index];
          print "npushw $count";
          while $count-- {
            my $word = $!instructions[++$index] +< 8;
            $word +|= $!instructions[++$index];
            print ",$word";
          }
          say '';
        }
        when 0x42 {
          say "ws";
        }
        when 0x43 {
          say "rs";
        }
        when 0x44 {
          say "wcvtp";
        }
        when 0x45 {
          say "rcvt";
        }
        when 0x46 .. 0x47 {
          say "gc[{$_ - 0x46}]";
        }
        when 0x48 {
          say "scfs";
        }
        when 0x49 .. 0x4a {
          say "md[{$_ - 0x49}]";
        }
        when 0x4b {
          say "mppem";
        }
        when 0x4d {
          say "flipon";
        }
        when 0x4e {
          say "flipoff";
        }
        when 0x4f {
          say "debug";
        }
        when 0x50 {
          say "lt";
        }
        when 0x51 {
          say "lteq";
        }
        when 0x52 {
          say "gt";
        }
        when 0x53 {
          say "gteq";
        }
        when 0x54 {
          say "eq";
        }
        when 0x55 {
          say "neq";
        }
        when 0x56 {
          say "odd";
        }
        when 0x57 {
          say "even";
        }
        when 0x58 {
          say "if";
        }
        when 0x59 {
          say "eif";
        }
        when 0x5a {
          say "and";
        }
        when 0x5b {
          say "or";
        }
        when 0x5c {
          say "not";
        }
        when 0x5d {
          say "deltap1";
        }
        when 0x5e {
          say "sdb";
        }
        when 0x5f {
          say "sds";
        }
        when 0x60 {
          say "add";
        }
        when 0x61 {
          say "sub";
        }
        when 0x62 {
          say "div";
        }
        when 0x63 {
          say "mul";
        }
        when 0x64 {
          say "abs";
        }
        when 0x65 {
          say "neg";
        }
        when 0x66 {
          say "floor";
        }
        when 0x67 {
          say "ceiling";
        }
        when 0x68 .. 0x6b {
          say "round[{$_ - 0x68}]";
        }
        when 0x6c .. 0x6f {
          say "nround[{$_ - 0x6c}]";
        }
        when 0x70 {
          say "wcvtf";
        }
        when 0x71 {
          say "deltap2";
        }
        when 0x72 {
          say "deltap3";
        }
        when 0x73 {
          say "deltac1";
        }
        when 0x74 {
          say "deltac2";
        }
        when 0x75 {
          say "deltac3";
        }
        when 0x76 {
          say "sround";
        }
        when 0x77 {
          say "s45round";
        }
        when 0x78 {
          say "jrot";
        }
        when 0x79 {
          say "jrof";
        }
        when 0x7a {
          say "roff";
        }
 #       when 0x7b {
 #         say "ron";
 #       }
        when 0x7c {
          say "rutg";
        }
        when 0x7d {
          say "rdtg";
        }
        when 0x7e {
          say "sangw";
        }
        when 0x80 {
          say "flippt";
        }
        when 0x81 {
          say "fliprgon";
        }
        when 0x82 {
          say "fliprgoff";
        }
        when 0x85 {
          say "scanctrl";
        }
        when 0x86 .. 0x87 {
          say "sdpvtl[{$_ - 0x86}]";
        }
        when 0x88 {
          say "getinfo";
        }
        when 0x89 {
          say "idef";
        }
        when 0x8a {
          say "roll";
        }
        when 0x8b {
          say "max";
        }
        when 0x8c {
          say "min";
        }
        when 0x8d {
          say "scantype";
        }
        when 0x8e {
          say "instctrl";
        }
        when 0x91 {
          say "getvariation";
        }
        when 0xb0 .. 0xb7 {
          push-bytes($_ - 0xaf, $!instructions, $index);
        }
        when 0xb8 .. 0xbf {
          push-words($_ - 0xb7, $!instructions, $index);
        }
        when 0xc0 .. 0xdf {
          say "mdrp[{($_ +& 0x10) ?? 1 !! 0} {($_ +& 0x08) ?? 1 !! 0} {($_ +& 0x04) ?? 1 !! 0} {$_ +& 0x03}]";
        }
        when 0xe0 .. 0xff {
          say "mirp[{($_ +& 0x10) ?? 1 !! 0} {($_ +& 0x08) ?? 1 !! 0} {($_ +& 0x04) ?? 1 !! 0} {$_ +& 0x03}]";
        }
        default {
          fail "Unknown instruction $_";
        }
      }
      ++$index;
    }
    say "end";
  }
}

# TODO -- actually store this data somewhere
sub read-class-def-table($buf) {
  my $format = $buf.read-uint16(0, BigEndian);
  given $format {
    when 1 {
      my $start-glyph-id = $buf.read-uint16(2, BigEndian);
      my $glyph-count    = $buf.read-uint16(4, BigEndian);
      my @class-value    = read-uint16-array($buf, 4, $glyph-count);
    }
    when 2 {
      my $class-range-count = $buf.read-uint16(2, BigEndian);
      my $offset = 4;
      for ^$class-range-count {
        my $first = $buf.read-uint16($offset, BigEndian); $offset += 2;
        my $last  = $buf.read-uint16($offset, BigEndian); $offset += 2;
        my $class = $buf.read-uint16($offset, BigEndian); $offset += 2;
      }
    }
    default {
      fail "Unknown Clas Definition Table format $format";
    }
  }
}

class Font::OpenType::Table::Gdef {
  has $.major-version         is rw;
  has $.minor-version         is rw;
  has $.glyph-class-def       is rw;
  has $.attach-list           is rw;
  has $.lig-caret-list        is rw;
  has $.mark-attach-class-def is rw;
  has $.mark-glyph-sets-def   is rw;
  has $.item-var-store        is rw;

  method read-table($table, $length) {
    my $major  = $table.read-uint16(0,  BigEndian);
    my $minor  = $table.read-uint16(2,  BigEndian);
    my $gcdoff = $table.read-uint16(4,  BigEndian);
    my $aloff  = $table.read-uint16(6,  BigEndian);
    my $lcloff = $table.read-uint16(8,  BigEndian);
    my $macoff = $table.read-uint16(10, BigEndian);
    $!major-version = $major;
    $!minor-version = $minor;
    my ($msgoff, $ivsoff) = (0, 0);
    if $minor >= 2 {
      $msgoff = $table.read-uint16(12, BigEndian);
    }
    if $minor >= 3 {
      $ivsoff = $table.read-uint16(14, BigEndian);
    }
    if $gcdoff {
      $!glyph-class-def = read-class-def-table($table.subbuf($gcdoff));
    }
    if $aloff {
    }
  }
}

class Font::OpenType::Table::Glyf {
  has @.glyphs is rw;

  method read-table($table, $length, $num-glyphs, $loca) {
    for ^$num-glyphs -> $i {
      my $length = $i < $num-glyphs - 1 ?? $loca[$i+1] - $loca[$i] !! $table.elems - $loca[$i];
      if $length {
        @!glyphs[$i] = Font::OpenType::Glyf::read-glyf($table.subbuf($loca[$i], $length));
      }
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
    my $major-version = $table.read-uint16(0, BigEndian);
    my $minor-version = $table.read-uint16(2, BigEndian);
    fail "Unknown font header table version $major-version.$minor-version"
      unless $major-version == 1 && $minor-version == 0;
    my $font-revision     = $table.read-uint32(4, BigEndian) / 65536.0;
    $!checksum-adjustment = $table.read-uint32(8,  BigEndian);
    $!magic-number        = $table.read-uint32(12,  BigEndian);
    $!flags               = $table.read-uint16(16,  BigEndian);
    $!units-per-em        = $table.read-uint16(18,  BigEndian);
    $!created             = $table.read-uint64(20,  BigEndian);
    $!modified            = $table.read-uint64(28,  BigEndian);
    $!x-min               = $table.read-uint16(36,  BigEndian);
    $!y-min               = $table.read-uint16(38,  BigEndian);
    $!x-max               = $table.read-uint16(40,  BigEndian);
    $!y-max               = $table.read-uint16(42,  BigEndian);
    $!mac-style           = $table.read-uint16(44,  BigEndian);
    $!lowest-rec-ppem     = $table.read-uint16(46,  BigEndian);
    $!font-direction-hint = $table.read-uint16(48,  BigEndian);
    $!index-to-loc-format = $table.read-uint16(50,  BigEndian);
    $!glyph-data-format   = $table.read-uint16(52,  BigEndian);
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
      my $aw  = $table.read-uint16($index, BigEndian); $index += 2;
      my $lsb = $table.read-uint16($index, BigEndian); $index += 2;
#      $!advanced-width.push: $aw;
#      $!left-side-bearing.push: $lsb;
    }
    while $i++ < $num-glyphs {
      my $lsb = $table.read-uint16($index, BigEndian);
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
    $!version  = $table.read-uint16(0, BigEndian);
    $!n-tables = $table.read-uint16(2, BigEndian);
    my $index = 4;
    for ^$!n-tables {
      my $version = $table.read-uint16($index, BigEndian); $index += 2;
      $!length    = $table.read-uint16($index, BigEndian); $index += 2;
      $!coverage  = $table.read-uint16($index, BigEndian); $index += 2;
      my $format = ($!coverage +> 8) +& 0xff;
      given $format {
        when 0 {
          my $n-pairs        = $table.read-uint16($index, BigEndian); $index += 2;
          my $search-range   = $table.read-uint16($index, BigEndian); $index += 2;
          my $entry-selector = $table.read-uint16($index, BigEndian); $index += 2;
          my $range-shift    = $table.read-uint16($index, BigEndian); $index += 2;
          my $subtable = Font::OpenType::Table::Kern::Table.new(:$n-pairs, :$search-range, :$entry-selector, :$range-shift);
          @!tables.push: $subtable;
          for ^$n-pairs {
            my $left  = $table.read-uint16($index, BigEndian); $index += 2;
            my $right = $table.read-uint16($index, BigEndian); $index += 2;
            my $value = $table.read-uint16($index, BigEndian); $index += 2;
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
    given $loc-format-type {
      when 0 {
        while $index < $length {
          @!loca.push: $table.read-uint16($index, BigEndian) * 2;
          $index += 2;
        }
      }
      when 1 {
        while $index < $length {
          @!loca.push: $table.read-uint32($index, BigEndian);
          $index += 4;
        }
      }
      default {
        fail "Unknown loca table format $loc-format-type, should be 0 or 1";
      }
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
    $!format        = $table.read-uint16(0, BigEndian);
    $!count         = $table.read-uint16(2, BigEndian);
    $!string-offset = $table.read-uint16(4, BigEndian);

    # read name records
    my $index = 6;
    for ^$!count {
      my $platform-id = $table.read-uint16($index, BigEndian); $index += 2;
      my $encoding-id = $table.read-uint16($index, BigEndian); $index += 2;
      my $language-id = $table.read-uint16($index, BigEndian); $index += 2;
      my $name-id     = $table.read-uint16($index, BigEndian); $index += 2;
      my $length      = $table.read-uint16($index, BigEndian); $index += 2;
      my $offset      = $table.read-uint16($index, BigEndian); $index += 2;
      @!name-record.push: %(
                           platform-id => $platform-id,
                           encoding-id => $encoding-id,
                           language-id => $language-id,
                           name-id     => $name-id,
                           length      => $length,
                           offset      => $offset,
                         );
    }

    # read lang tag records
    given $!format {
      when 0 {
      }
      when 1 {
        $!lang-tag-count = $table.read=uint16($index, BigEndian);
        for ^$!lang-tag-count {
          my $length = $table.read-uint16($index, BigEndian); $index += 2;
          my $offset = $table.read-uint16($index, BigEndian); $index += 2;
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
        $!num-glyphs = $table.read-uint16(28, BigEndian);
        my $index = 30;
        @!glyph-name-index = read-uint16-array($table, $index, $num-glyphs);
        @!names            = read-uint16-array($table, $index + $num-glyphs*2, $num-glyphs);
      }
      when 2.5 {
        my $index = 30;
        $!num-glyphs = $table.read-uint16(28, BigEndian);
        @!glyph-name-index = read-uint16-array($table, $index, $num-glyphs);
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

# The webf table is undocumented
# This class exists simply to stop font loading from failing; the table will be ignored

class Font::OpenType::Table::Webf {
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
    my $buf            = $fh.read: 8;
    my $num-tables     = $buf.read-uint16(0, BigEndian);
    my $search-range   = $buf.read-uint16(2, BigEndian);
    my $entry-selector = $buf.read-uint16(4, BigEndian);
    my $range-shift    = $buf.read-uint16(6, BigEndian);

    # read table record entries
    for ^$num-tables {
      $buf = $fh.read: 16;
      my $table-tag = $buf.subbuf(0, 4).decode(enc => 'utf8-c8');
      my $check-sum = $buf.read-uint32(4,  BigEndian);
      my $offset    = $buf.read-uint32(8,  BigEndian);
      my $length    = $buf.read-uint32(12, BigEndian);
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
        when 'cmap' {
          %!table<cmap> = Font::OpenType::Table::Cmap.new;
          %!table<cmap>.read-table($buf, $length);
        }
        when 'cvt ' {
          %!table<cvt> = Font::OpenType::Table::Cvt.new();
          %!table<cvt>.read-table($buf, $length);
        }
        when 'FFTM' {
          # undocumented FontForge specific table
        }
        when 'fpgm' {
          %!table<fpgm> = Font::OpenType::Table::Fpgm.new();
          %!table<fpgm>.read-table($buf, $length);
        }
        when 'gasp' {
        }
        when 'GDEF' {
          %!table<GDEF> = Font::OpenType::Table::Gdef.new();
          %!table<GDEF>.read-table($buf, $length);
        }
        when 'glyf' {
          self.read-table($fh, 'loca') unless %!table<loca>.defined;
          self.read-table($fh, 'maxp') unless %!table<maxp>.defined;
          %!table<glyf> = Font::OpenType::Table::Glyf.new();
          %!table<glyf>.read-table($buf, $length, %!table<maxp>.num-glyphs, %!table<loca>.loca);
        }
        when 'GPOS' {
        }
        when 'GSUB' {
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
        when 'OS/2' {
          %!table<OS/2> = Font::OpenType::Table::OS2.new();
          %!table<OS/2>.read-table($buf, $length);
        }
        when 'post' {
	  %!table<post> = Font::OpenType::Table::Post.new;
	  %!table<post>.read-table($buf, $length);
        }
        when 'prep' {
	  %!table<prep> = Font::OpenType::Table::Prep.new;
	  %!table<prep>.read-table($buf, $length);
        }
        when 'webf' {
	  %!table<webf> = Font::OpenType::Table::Webf.new;
	  %!table<webf>.read-table($buf, $length);
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

#my $filename = '/home/kevinp/Fonts/Univers/UniversBlack.ttf';
my $filename = '/home/kevinp/Fonts/defharo_bola-ocho/bola-ocho-demo-ffp.ttf';

my $font = Font::OpenType::read-file($filename);
$font.table<glyf>.glyphs[34].dump;
