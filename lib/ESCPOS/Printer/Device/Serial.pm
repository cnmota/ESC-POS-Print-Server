package ESCPOS::Printer::Device::Serial;

use Moo;

has baud => (
  is => 'rw',
  required => 1,
  default => sub { 9600 }, 
);

has databits => (
  is => 'rw',
  required => 1,
  default => sub { 8 }
);

has stopbits => (
  is => 'rw',
  required => 1,
  default => sub { 1 }
);

has parity => (
  is => 'rw',
  required => 1,
);

has control => (
  is => 'rw',
  required => 1,
);

sub init {
  my $self = shift;

  #CALL STTY IN THE FUTURE
}

1;
