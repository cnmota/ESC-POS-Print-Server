package Printer::TM::BitArray;

use Moo;

use GD;

has dots => (
  is => 'rw'
);

has width => (
  is => 'rw'
);

has height => (
  is => 'rw'
);

has dpis => (
  is => 'rw',
  required => 0,
  default => sub { 8 }
);

has path => (
  is => 'rw',
  required => 1
);

sub BUILD {
  my $self = shift;
  my $dpis = shift;
  
  my $img = GD::Image->new( $self->path() );
  
  my ($width,$height) = $img->getBounds();

  $self->width( $width );
  $self->height( $height );
  $self->dots( [] );

  $self->width() = 575 if ( $self->width() > 575 );
  
  #WE STILL NEED TO RESIZE THE IMAGE PROPERLY

  for (my $hi = 0; $hi < $self->height(); $hi++) {
    for (my $wi = 0; $wi < $self->width(); $wi++) {
      my ($r,$g,$b) = $img->rgb( $img->getPixel($wi,$hi) );

      $r = 256 + $r if ($r < 0);
      if ( $r > 200 && $b > 200 && $g > 200 ) {
        push @{$self->dots()}, 0
      } else {
        push @{$self->dots()}, 1
      }
    }
  }
}

1;
