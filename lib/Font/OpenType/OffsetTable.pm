unit class Font::OpenType::OffsetTable;

use v6;

has $.sfntVersion;
has $.nuTables;
has $.searchRange;
has $.entrySelector;
has $.rangeShift;

method read-offset-table($fh) {
  $fh.seek: 0, SeekFromBeginning;
  my $buf = $fh.read: 16;
  ($!sfntVersion, $!nuTables, $!searchRange, $!entrySelector, $!rangeShift) = $buf.unpack: 'NNnnn';
}
