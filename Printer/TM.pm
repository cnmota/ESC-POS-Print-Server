package Printer::TM;

use Moo;

use IO::Handle;
use GD::Barcode::QRcode;

use Printer::TM::BitArray;
#use Printer::TM::Serial;
#use Printer::TM::Parallel;
#use Printer::TM::USB;

has char_device => (
  is => 'ro',
  required => 1,
  default => sub { '/dev/tts/USB0' }
);

has document => (
  is => 'rw',
  required => '0',
  default => sub { '' }
);

has handle => (
  is => 'ro',
  required => 1,
  default => sub {
    my $self = shift;

    open(my $fh, ">", $self->char_device() );
    binmode($fh);
    $fh->autoflush;

    return $fh;
  }
);

sub BUILD {
  my $self = shift;

  #REINITIALIZE PRINTER
  $self->reset();
}

sub reset {
  my $self = shift;

  $self->document( chr(27) . "@"; );
}

sub font {
  my $self = shift;
  my $type = shift;

  if ( uc($type) eq uc('bold') ) {
    $self->append( chr(27)."!".chr(32) );
  } else {
    $self->append( chr(27)."!".chr(0) );
  }
}

sub align {
  my $self = shift;
  my $alignment = shift
  
  if ( uc($alignment) eq uc('right') ) {
    $self->append( chr(27)."a".chr(50) );
  } elsif ( uc($alignment) eq uc('center') ) {   
    $self->append( chr(27)."a".chr(49) );
  } else {
    $self->append( chr(27)."a".chr(48) );   
  }
}

sub qrcode {
  my $self = shift;
  my $data = shift;
  
  open(my $out, ">", "/tmp/qrcode.png");
  binmode($out);
  
  my $o = GD::Barcode::QRcode->new($data, { Ecc => 'Q', Version=> 4, ModuleSize => 4 } );
  my $r = $o->plot();
  
  print $out $r->png;
  close $out;
  
  $self->image("/tmp/qrcode.png",24);
}

sub cut {
  my $self = shift;
  my $lines = shift || 1;

  my $feed = chr($lines);

  $self->append( chr(29) . "V". chr(65) . $feed );
}

sub text {
  my $self = shift;
  my $str = shift;
  
  $self->append( $str );
}

sub append {
  my $self = shift;
  my $str = shift;

  $self->document( $self->document() . $str );
}

sub print {
  my $self = shift;
  
  my $fh = $self->handle();
  print $fh $self->document();

  $self->document(''); 
}

sub image {
  my $self = shift;  
  my $path = shift;
  my $density = shift || 0;

  my $dpis = $density ? 24 : 8 
  my $print_mode = $dpis == 24 ? 33 : 0;
        
  my $nlow = $bit_array->width() % 256;
  my $nhigh = ($bit_array->width() >> 8) % 256;
  
  my $offset = 0;
  my $line_size = 0;

  my $bit_array = Printer::TM::BitArray->new( path => $path, dpis => $dpis );  

  $self->append( chr(27) . "3" . chr(24) );
  
  while($offset < $bit_array->height()) {
    $self->append(chr(27) . "*" . chr($print_mode));                   # Single or double density
    $self->append(chr($nlow) . chr($nhigh));                           # low byte and high byte

    for (my $x = 0; $x < $bit_array->width(); ++$x) {                  # walk through columns
      for (my $k = 0; $k < $dots/8; ++$k) {                            # 24 dots = 24 bits = 3 bytes ($k)
        my $byte = 0;                                                  # start a byte

        for (my $b = 0; $b < 8; ++$b) {                                # 1 byte = 8 bits ($b)
          my $y = ((($offset / 8) + $k) * 8) + $b;                     # calculate $y position
          my $i = ($y * $bit_array->width()) + $x;                     # calculate pixel position

          # check if bit exists, if not, zero it
          # ====================================

          my $bit = 0;

          if ( defined $bit_array->dots()->[$i] ) {
            $bit = $bit_array->dots()->[$i] ? 1 : 0;
          } else {
            $bit = 0;
          }

          $byte |= $bit << (7 - $b);                  # shift bit and record byte
        }

        $self->append(chr($byte));                 # attach the byte
        $line_size++;
      }
    }

    $offset += $dots;
    $self->append(chr(10));                          # line feed
    $line_size = 0;
  }
}


1;
