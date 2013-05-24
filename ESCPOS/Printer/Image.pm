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
	default => sub { '8SD' }
);

has density_map => (
	is => 'ro',
	required => 0,
	default => sub {
	 		{
	 			'24DD' => { print_mode => 33, vbits => 24, scalex => 1,       scaley => 1 },
	 			'24SD' => { print_mode => 32, vbits => 24, scalex => 90/180,  scaley => 180/180 },
	 			'8DD' =>  { print_mode =>  1, vbits =>  8, scalex => 180/180, scaley => 60/180 },	 			
	 			'8SD' =>  { print_mode =>  0, vbits =>  8, scalex => 90/180,  scaley => 60/180 }
	 		}
	 }
);

sub BUILD {
	my $self = shift;
	
	my $img = GD::Image->new( $self->path() );
	$img = $self->resize( $img );
	
	my ($width,$height) = $img->getBounds();

	print STDERR "FINAL WIDTH : $width x $height\n";

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

	my $factor = 1;

	# SCALE IMAGE IF IMAGE IS BIGGER THAN HD MAX SIZE
	if ($width > $max_width) {
		$factor = $max_width / $width;
	}

	print STDERR "## ORIG WIDTH : $width\n";
	print STDERR "## ORIG HEIGHT : $height\n";
	print STDERR $self->density()."\n";

	#IMAGE IS SD WE MUST SCALE DOWN FROM HD
	if ($self->density() ne '24DD') {
		$factor = $factor * $self->density_map()->{ $self->density() }->{scalex};
	}

	my $scalex = $factor;
	my $scaley = $factor * $self->density_map()->{ $self->density() }->{scaley} / $self->density_map()->{ $self->density() }->{scalex};

	print STDERR "## SCALEX : $scalex\n";
	print STDERR "## SCALEY : $scaley\n";

	my $nwidth = int($width * $scalex);
	my $nheight = int($height * $scaley);

	print STDERR "## NWIDTH: $nwidth\n";
	print STDERR "## NHEIGHT: $nheight\n";

	if ($scalex == 1 && $scaley == 1) {
		return $orig;
	} else {
		my $image = GD::Image->new($nwidth, $nheight);
		$image->copyResampled( $orig,0,0,0,0,$nwidth,$nheight,$width,$height );

		return $image;
	}
}

sub escpos {
	my $self = shift; 
	my $out = "";

	my $dpis = $self->density_map()->{ $self->density() }->{vbits}; # 'HD' ? 24 : 8;
	my $print_mode = $self->density_map()->{ $self->density() }->{print_mode};

	print STDERR "$dpis ## $print_mode\n";
				
	my $nlow = $self->width() % 256;
	my $nhigh = ($self->width() >> 8) % 256;
	
	my $offset = 0;
	my $line_size = 0;

	$out .= chr(27) . "3" . chr(24);
	
	while($offset < $self->height()) {
		$out .= chr(27) . "*" . chr($print_mode);
		$out .= chr($nlow) . chr($nhigh);

		for (my $x = 0; $x < $self->width(); ++$x) {
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

	return $out;
}

1;