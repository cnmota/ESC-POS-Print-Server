package ESCPOS::Printer::Image;

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

sub convert {
	my $self = shift; 
	my $path = shift;
	my $density = shift || 0;

	my $dpis = $density eq 'HD' ? 24 : 8 
	my $print_mode = $dpis == 24 ? 33 : 0;
				
	my $nlow = $bit_array->width() % 256;
	my $nhigh = ($bit_array->width() >> 8) % 256;
	
	my $offset = 0;
	my $line_size = 0;

	my $bit_array = ESCPOS::Printer::Image->new( path => $path, dpis => $dpis );	

	$self->append( chr(27) . "3" . chr(24) );
	
	while($offset < $bit_array->height()) {
		$self->append(chr(27) . "*" . chr($print_mode));									 # Single or double density
		$self->append(chr($nlow) . chr($nhigh));													 # low byte and high byte

		for (my $x = 0; $x < $bit_array->width(); ++$x) {								 # walk through columns
			for (my $k = 0; $k < $dots/8; ++$k) {													 # 24 dots = 24 bits = 3 bytes ($k)
				my $byte = 0;																								 # start a byte

				for (my $b = 0; $b < 8; ++$b) {															 # 1 byte = 8 bits ($b)
					my $y = ((($offset / 8) + $k) * 8) + $b;										 # calculate $y position
					my $i = ($y * $bit_array->width()) + $x;										 # calculate pixel position

					# check if bit exists, if not, zero it
					# ====================================

					my $bit = 0;

					if ( defined $bit_array->dots()->[$i] ) {
						$bit = $bit_array->dots()->[$i] ? 1 : 0;
					} else {
						$bit = 0;
					}

					$byte |= $bit << (7 - $b);									# shift bit and record byte
				}

				$self->append(chr($byte));								 # attach the byte
				$line_size++;
			}
		}

		$offset += $dots;
		$self->append(chr(10));												 # line feed
		$line_size = 0;
	}
}

1;