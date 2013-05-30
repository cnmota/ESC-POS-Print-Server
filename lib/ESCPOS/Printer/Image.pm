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
	 			'24DD' => { print_mode => 33, vbits => 24, scalex => 1,			 scaley => 1 },
	 			'24SD' => { print_mode => 32, vbits => 24, scalex => 90/180,	scaley => 180/180 },
	 			'8DD' =>	{ print_mode =>	1, vbits =>	8, scalex => 180/180, scaley => 60/180 },	 			
	 			'8SD' =>	{ print_mode =>	0, vbits =>	8, scalex => 90/180,	scaley => 60/180 }
	 		}
	 }
);

has dither_method => (
	is => 'ro',
	required => 0,
	default => sub { '' }
);

sub BUILD {
	my $self = shift;
	
	my $img = GD::Image->new( $self->path() );
	$img = $self->resize( $img );

	$self->to_png($img, "resized.png");

	if ($self->dither_method() eq 'Atkinson') {
		$img = $self->grayscale( $img );
		$self->to_png($img, "gray.png");
		$img = $self->dither_atkinson( $img );
	} elsif ($self->dither_method eq 'Floyd') {
		$img = $self->grayscale( $img );
		$img = $self->dither_floyd( $img );
	} else {
		$img = $self->resize( $img, 1 )
	}

	$self->to_png($img, $self->dither_method().".png");

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

sub inv_gam_sRGB {
	my $ic = shift;
	
	my $c = $ic/255;

	if ( $c <= 0.04045 ) {
		return $c/12.92;
	} else { 
		return (($c+0.055)/(1.055)) ** 2.4;
	}
}

sub gam_sRGB {
	my $v = shift;

	if( $v <= 0.0031308) {
		$v *= 12.92;
	} else { 
		$v = 1.055*($v ** (1.0/2.4)) - 0.055;
		return int($v * 255 +.5);
	}
}

sub grayscale_pixel {
	my ($r, $g, $b) = @_;

	my $rY = 0.212655;
	my $gY = 0.715158;
	my $bY = 0.072187;

	return &gam_sRGB(
		$rY * inv_gam_sRGB($r) + $gY * inv_gam_sRGB($g) + $bY * inv_gam_sRGB($b) 
	);
}

sub grayscale {
	my $self = shift;
	my $img = shift;
	#SHOULD BE MOVED TO FILTER ROLE

	#CONVERT IMAGE TO GREYSSCALE
	if ( defined $img->colorsTotal() ) {
		for (my $i = 0; $i < $img->colorsTotal(); $i++) {
			my ($r, $g, $b) = $img->rgb($i);
			my $gray = &grayscale_pixel( $r, $g, $b );

			$img->colorDeallocate($i);
			$img->colorAllocate($gray,$gray,$gray);
		}
	}	else {
		my $x_max = $img->width();
		my $y_max = $img->height();

		for (my $y = 0; $y < $y_max; $y++) {
			for (my $x = 0; $x < $x_max; $x++) {	
				my ($r, $g, $b) = $img->rgb( $img->getPixel($x,$y) );
				my $gray = &grayscale_pixel( $r, $g, $b );

				my $i = $img->colorExact( $gray, $gray, $gray );
				$img->setPixel($x, $y, $i);
			}
		}	
	}	

	return $img;
}

sub rgb2hex {
	my $self = shift;
	my ($r, $g, $b) = @_;

	return hex( sprintf("0x%0X%0X%0X", $r, $g, $b) );
}

sub dither_atkinson {
	my $self = shift;
	my $img = shift;

	my $img_xy = [];
	my $x_max = $img->width();
	my $y_max = $img->height();

	my $threshold = $self->rgb2hex( 255, 255, 255 )*0.5;

	for (my $x = 0; $x <= $x_max; $x++) {
		$img_xy->[$x] = [] unless defined $img_xy->[$x];
		for (my $y = 0; $y <= $y_max; $y++) {
			$img_xy->[$x]->[$y] = $self->rgb2hex( $img->rgb( $img->getPixel($x,$y) ) );
		}
	}

	my $img_dither = GD::Image->new($x_max, $y_max, 1);
	my $white = $img_dither->colorAllocate(255,255,255);
	my $black = $img_dither->colorAllocate(0,0,0); 

	for (my $y = 0; $y < $y_max; $y++) {
		for (my $x = 0; $x < $x_max; $x++) {
			my $oldpixel = $img_xy->[$x]->[$y];
			my $newpixel = $oldpixel > $threshold ? $white : $black;
			my $quant_error = $oldpixel - $newpixel;
			my $error_diffusion = (1/8)*$quant_error; 

			$img_dither->setPixel($x,$y,$newpixel ? $white : $black);

			$img_xy->[$x+1]->[$y] += $error_diffusion;
			$img_xy->[$x+2]->[$y] += $error_diffusion;
			$img_xy->[$x-1]->[$y+1] += $error_diffusion;
			$img_xy->[$x]->[$y+1] += $error_diffusion;
			$img_xy->[$x+1]->[$y+1] += $error_diffusion;
			$img_xy->[$x]->[$y+2] += $error_diffusion;
		}
	}

	return $img_dither;
}

sub dither_floyd {
	my $self = shift;
	my $img = shift;

	my $img_xy = [];
	my $x_max = $img->width();
	my $y_max = $img->height();

	my $threshold = $self->rgb2hex( 255, 255, 255 )*0.5;

	for (my $x = 0; $x <= $x_max; $x++) {
		$img_xy->[$x] = [] unless defined $img_xy->[$x];
		for (my $y = 0; $y <= $y_max; $y++) {
			$img_xy->[$x]->[$y] = $self->rgb2hex( $img->rgb( $img->getPixel($x,$y) ) );
		}
	}

	my $img_dither = GD::Image->new($x_max, $y_max, 1);
	my $white = $img_dither->colorAllocate(255,255,255);
	my $black = $img_dither->colorAllocate(0,0,0); 

	my $w1=7/16;
	my $w2=3/16;
	my $w3=5/16;
	my $w4=1/16;

	for (my $y = 0; $y < $y_max; $y++) {
		for (my $x = 0; $x < $x_max; $x++) {
			my $oldpixel = $img_xy->[$x]->[$y];
			my $newpixel = $oldpixel > $threshold ? $white : $black;
			my $quant_error = $oldpixel - $newpixel;

			$img_dither->setPixel($x,$y,$newpixel);

			if ($x + 1 <= $x_max) {
				my $oldpixel = $img_xy->[$x+1]->[$y];
				my $newpixel = $oldpixel + ($w1 * $quant_error);

				$img_xy->[$x+1]->[$y] = $newpixel;
			}

			if (($x-1 > 0) && ($y+1 < $y_max)) {
				my $oldpixel = $img_xy->[$x-1]->[$y+1];
				my $newpixel = $oldpixel + ($w2 * $quant_error);

				$img_xy->[$x-1]->[$y+1] = $newpixel;
			}

			if ($y + 1 <= $y_max) {
				my $oldpixel = $img_xy->[$x]->[$y+1];
				my $newpixel = $oldpixel + ($w3 * $quant_error);

				$img_xy->[$x]->[$y+1] = $newpixel;
			}

			if (($x + 1 <= $x_max) && ($y + 1 <= $y_max)) {
				my $oldpixel = $img_xy->[$x+1]->[$y+1];
				my $newpixel = $oldpixel + ($w4 * $quant_error);

				$img_xy->[$x+1]->[$y+1] = $newpixel;
			}
		}
	}

	return $img_dither;
}

sub resize {
	my $self = shift;
	my $orig = shift;
	my $no_true_color = shift || 0;

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
		my $image = GD::Image->new($nwidth, $nheight, $no_true_color ? 0 : 1);
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

sub to_png {
	my $self = shift;
	my $img = shift;
	my $filename = shift;

	my $png_data = $img->png(0);
	open my $fh, ">", $filename || die;
	binmode($fh);
	print $fh $png_data;
	close $fh;
}

1;