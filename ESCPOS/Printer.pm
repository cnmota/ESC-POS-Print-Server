package ESCPOS::Printer;

use Moo;
use GD::Barcode::QRcode;

use ESCPOS::Printer::Image;
use ESCPOS::Printer::Buffer;
use ESCPOS::Printer::Device;

has buffer => (
	is => 'ro',
	required => 1
);

has device => (
	is => 'ro',
	required => 1
);

has max_width => (
	is => 'ro',
	required => 1
);

has can_do_color => ();

has can_do_drawer => ();

has can_do_image => ();

has can_do_cut => ();

sub BUILD {
	my $self = shift;

		#INIT PRINTER

	$self->buffer()->push( chr(27) . "@" );
}

sub bold {

}

sub underline {
	my $self = shift;
	my $mode = shift;
		
	$self->buffer()->push( chr(27)."-" );
		
	if ($mode) {
		$self->buffer()->push( chr(49) );
	} else {
			$self->buffer()->push( chr(48) );
	}
}

sub double_width {

}

sub double_height {

}

sub italic {

}

sub align {
	my $self = shift;
	my $alignment = shift || 'L';
		
	if ($alignment eq 'R') {
			$self->buffer()->push( chr(27)."a".chr(50) );
	} elsif ($alignment eq 'C') {	 
			$self->buffer()->push( chr(27)."a".chr(49) );
	} else {
			$self->buffer()->push( chr(27)."a".chr(48) );	 
	}
}

sub cut {
	my $self = shift;
		my $lines = shift || 1;

		my $feed = chr($lines);

		$self->buffer()->push( chr(29) . "V". chr(65) . $feed );
}

sub drawer {

}

sub linefeed {
	my $self = shift

	$self->buffer()->push( chr(10) );
}

sub text {
	my $self = shift;
	my $str = shift;

	$self->buffer()->push( $str );

}

sub qrcode {
	my $self = shift;
	my $data = shift;

	my $o = GD::Barcode::QRcode->new($data, { Ecc => 'Q', Version=> 4, ModuleSize => 4 } );
	my $r = $o->plot();	
		
	open(my $out, ">", "/tmp/qrcode.png");
	binmode($out);
	print $out $r->png;
	close $out;
		
	$self->image("/tmp/qrcode.png",'HD');
}

sub barcode {

}

sub reset {

}

sub image {
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

		for (my $x = 0; $x < $bit_array->width(); ++$x) {									# walk through columns
			for (my $k = 0; $k < $dots/8; ++$k) {														# 24 dots = 24 bits = 3 bytes ($k)
				my $byte = 0;																									# start a byte

				for (my $b = 0; $b < 8; ++$b) {																# 1 byte = 8 bits ($b)
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
		$self->append(chr(10));													# line feed
		$line_size = 0;
	}
}

sub print {
	my $self = shift;
		
		$self->device()->print( $self->buffer()->dump() );

		$self->buffer()->reset();
}