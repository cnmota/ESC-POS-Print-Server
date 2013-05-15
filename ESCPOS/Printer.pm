package ESCPOS::Printer;

#AUTHORS: carlosnunomota@gmail.com, karlus@karlus.net

use Moo;
use GD::Barcode::QRcode;

use ESCPOS::Printer::Image;
use ESCPOS::Printer::Buffer;
use ESCPOS::Printer::Device;

has buffer => (
	is => 'ro',
	required => 0,
	default => sub {
		return ESCPOS::Printer::Buffer->new();
	}
);

has device => (
	is => 'ro',
	required => 1
);

has max_width => (
	is => 'ro',
	required => 0,
	default => sub { 576 }
);

has can_do_color => (
	is => 'rw',
	required => 0,
	default => sub { 1 }
);

has can_do_drawer => (
	is => 'rw',
	required => 0,
	default => sub { 1 }
);

has can_do_image => (
	is => 'rw',
	required => 0,
	default => sub { 1 }
);

has can_do_cut => (
	is => 'rw',
	required => 0,
	default => sub { 1 }
);

sub BUILD {
	my $self = shift;

		#INIT PRINTER

	$self->buffer()->push( chr(27) . "@" );
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

sub linefeed {
	my $self = shift;

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
		
	$self->image("/tmp/qrcode.png",'SD');
}

sub image {
	my $self = shift;
	my $path = shift;
	my $density = shift || 'SD';

	my $image = ESCPOS::Printer::Image->new( path => $path, density => $density);

	$self->buffer()->push( $image->escpos() );
}

sub print {
	my $self = shift;
		
	$self->device()->print( $self->buffer()->dump() );

	$self->buffer()->clear();
}

sub bold {
}

sub barcode {
}

sub reset {
}

sub drawer {
}

sub double_width {
}

sub double_height {
}

sub italic {
}

1;