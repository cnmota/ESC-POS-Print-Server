package ESCPOS::Printer::Buffer;

use Moo;

has data => (
  is => 'rw',
  required => 0,
  default => sub { 
    return '';
  }
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

sub search_replace {
  my $self = shift;
  my $search = shift;
  my $replace = shift;

  if (defined $search && defined $replace) {
    print STDERR "APPLY PATTERN\n";
    my $data = $self->data();
    $data =~ s/$search/$replace/g;

    $self->data( $data );
  }
}

1;
