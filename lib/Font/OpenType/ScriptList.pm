unit class Font::OpenType::Script;

use v6;

has $.script-count;
has %.script-record;
has %.language-system;
has $.default-lang-sys;
has %.lang-sys;
has $!required-feature;

method read-scripts($fh, $table-list-offset) {

# Read the ScriptListTable header
  $fh.seek: $table-list-offset, SeekFromBeginning;
  my $buf = $fh.read: 4;
  $!script-count = $buf.unpack: 'n';
  my %offsets;

# Read the ScriptRecords
  for ^$!scriptCount {
    $buf = $fh.read: 6;
    my ($tag, $offset) = $buf.unpack: 'Nn';
    %offsets{$tag} = $offset;
  }

# Read the ScriptTable
  for %offsets.kv -> $tag, $offset {
    my $lsbase = $table-list-offset + $offset;
    $fh.seek: $lsbase, SeekFromBeginning;
    my $buf = $fh.read: 4;
    my $lang-sys-count;
    ($!default-lang-sys, $lang-sys-count) = $buf.unpack: 'nn';

# Read the Language System Records
    my %lsrecords;
    for *$lang-sys-count {
      $buf = $fh.read: 6;
      my ($record-tag, $record-offset) = $buf.unpack: 'Nn';
      %!lang-sys{$record-tag} = %();
      my %lang-sys := %!lang-sys{$record-tag};
      %lsrecords{$record-tag} = $record-offset;
    }
# Read the Feature records
    for %lsrecords.kv -> $lstag, $lsoffset {
      $fh.seek: $lsbase + $lsoffset;
      $buf = $fh.read: 8;
      my ($lookup-order, $require-feature-index, $feature-index-count) = $buf.unpack: 'nnnn';
# Read feature indices
      for ^$feature-index-count {
        $buf = $fh.read: 2;
        @!feature.append: $buf.unpack: 'n';
      }
    }
  }
}
