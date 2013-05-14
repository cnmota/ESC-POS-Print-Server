package ESCPOS::Printer::Image;

use Moo;
use GD;

has dots => (
	is => 'rw',
	default => sub { return [] }
);

has width => (
	is => 'rw',
	required => 0
);

has height => (
	is => 'rw',
	required => 0
);

has dpis => (
	is => 'rw',
	required => 0,
	default => sub { 8 }
);

has path => (
	is => 'rw',
	required => 1,
);

has max_width => (
	is => 'rw',
	required => 0,
  default => sub {
  	return 576;
  }
);

#DENSITY
# HD => 
has density => (
	is => 'rw',
	required => 0,
  default => sub { 'SD' }
);

has density_map => (
	 is => 'ro',
	 required => 0,
	 default => sub {
	 	  {
	 	  	'HD' => { vdpi => 180, hdpi => 180, vbits => 24, scalex => 1, scaley => 1 },
	 	  	'SD' => { vdpi => 60, hdpi => 90, vbits => 8, scalex => 60/180, scaley => 90/180 }
	 	  }
	 }
);

sub BUILD {
	my $self = shift;
	
	my $img = GD::Image->new( $self->path() );
	$img = $self->resize( $img );
	
	my ($width,$height) = $img->getBounds();

	$self->width( $width );
	$self->height( $height );
	$self->dots( [] );

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

sub resize {
	my $self = shift;
	my $orig = shift;

  my ($width,$height) = $orig->getBounds();

  my $max_width = $self->max_width();
  $max_width = int( $max_width * $self->density_map()->{ $self->density() }->{scalex} );

  if ($width > $max_width) {
  	my $scalex = $max_width / $width;
  	my $scaley = $scalex * $self->density_map()->{ $self->density() }->{scalex} / $self->density_map()->{ $self->density() }->{scaley};

    my $nwidth = int($width * $scalex);
    my $nheight = int($height * $scaley);

    my $image = GD::Image->new($nwidth, $nheight);
    $image->copyResampled( $orig,0,0,0,0,$nwidth,$nheight,$width,$height );

    return $image;
  } else {
  	return $orig;
  }
  
}

sub escpos {
	my $self = shift; 
	my $out = "";

	my $dpis = $self->density_map()->{ $self->density() }->{vbits}; # 'HD' ? 24 : 8;
	my $print_mode = $dpis == 24 ? 33 : 0;
				
	my $nlow = $self->width() % 256;
	my $nhigh = ($self->width() >> 8) % 256;
	
	my $offset = 0;
	my $line_size = 0;

	$out .= chr(27) . "3" . chr(24);
	
	while($offset < $self->dots()->height()) {
		$out .= chr(27) . "*" . chr($print_mode);
		$out .= chr($nlow) . chr($nhigh);

		for (my $x = 0; $x < $self->dots()->width(); ++$x) {
			for (my $k = 0; $k < $dpis/8; ++$k) {
				my $byte = 0;

				for (my $b = 0; $b < 8; ++$b) {
					my $y = ((($offset / 8) + $k) * 8) + $b;
					my $i = ($y * $self->width()) + $x;

					my $bit = 0;

					if ( defined $self->dots()->[$i] ) {
						$bit = $self->dots()->[$i] ? 1 : 0;
					} else {
						$bit = 0;
					}

					$byte |= $bit << (7 - $b);									# shift bit and record byte
				}

				$out .= chr($byte);								 # attach the byte
				$line_size++;
			}
		}

		$offset += $dpis;
		$out .= chr(10);												 # line feed
		$line_size = 0;
	}
}

1;