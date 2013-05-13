package ESCPOS::Printer::Device;

use Moo;

has port => (
  is => 'rw',
  required => 0,
  default => '/dev/tts/USB0'
);

sub BUILD {
  my $self = shift;

  $self->init();
}

sub init {}

sub print {
  my $self = shift;
  my $data = shift;

  open my $fh, ">", $self->port();
  binmode($fh);

  local $| = 1;
  
  print $fh $data;
  close $fh;
}

1;
