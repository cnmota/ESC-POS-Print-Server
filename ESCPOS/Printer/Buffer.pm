package ESCPOS::Printer::Buffer;

use Moo;

has data => (
  is => 'rw',
  required => 0,
);

sub clear {
  my $self = shift;

  $self->data('');
}

sub push {
  my $self = shift;
  my $str = shift;

  $self->data( $self->data() . $str );
}

sub pull {
  my $self = shift;

  my $last = undef;
  my @new = ();

  foreach my $row ( split(/\n/, $self->data() ) ) {
    $last = $row;
  }

  return $last;
}

sub dump {
  my $self = shift;

  return $self->data();
}

1;
