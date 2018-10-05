unit class Font::OpenType::TableRecord;

use v6;

has $.tableTag;
has $.checkSum;
has $.offset;
has $.length;

method read-table-record($fh) {
  $fh.seek: 16, SeekFromBeginning;
  my $buf = $fh.read: 16;
  ($!tableTag, $!checkSum, $!offset, $!length) = $buf.unpack: 'NNNN';
}
