package Printer::Receipt;

use Moo;

use IO::Handle;
use GD::Barcode::QRcode;

use Printer::Receipt::BitArray;

#use Printer::TM::Serial;
#use Printer::TM::Parallel;
#use Printer::TM::USB;

has dots => (
  is => 'rw',
  required => '0',
  default => sub { 8 }  
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
    open(my $fh, ">", '/dev/tts/USB0');
    binmode($fh);
    $fh->autoflush;

    return $fh;
  }
);

sub BUILD {
  my $self = shift;

  #REINITIALIZE PRINTER
  my $esc_pos_command = $self->kbyte(27) . "@";

  $self->document($esc_pos_command);
}

sub image {
  my $self = shift;
  my $path = shift;
  my $dots = shift || 24;
  
  print STDERR "### $dots\n";
  
  my $bit_array = Printer::Receipt::BitArray->new(path => $path);

  $self->output();                                      # empty buffer
  
  $self->append( $self->kbyte(27) . "3" . $self->kbyte(24) );
  
  my $nlow = $bit_array->width() % 256;
  my $nhigh = ($bit_array->width() >> 8) % 256;
  
  my $offset = 0;
  my $line_size = 0;
  
  while($offset < $bit_array->height()) {
    $self->append($self->kbyte(27) . "*" . $self->kbyte( $dots == 24 ? 33 : 0 ));        # 24 dot double density
    $self->append($self->kbyte($nlow) . $self->kbyte($nhigh));       # low byte and high byte

    for (my $x = 0; $x < $bit_array->width(); ++$x) {         # walk through columns
      for (my $k = 0; $k < $dots/8; ++$k) {                        # 24 dots = 24 bits = 3 bytes ($k)
        my $byte = 0;                                     # start a byte

        for (my $b = 0; $b < 8; ++$b) {                     # 1 byte = 8 bits ($b)
          my $y = ((($offset / 8) + $k) * 8) + $b;       # calculate $y position
          my $i = ($y * $bit_array->width()) + $x;       # calculate pixel position

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
        print STDERR "$byte\n" if ($byte > 255 || $byte < 0); 

        $self->append(chr($byte));                 # attach the byte
        $line_size++;
      }
    }

    $offset += $dots;
    $self->append($self->kbyte(10));                          # line feed
    $line_size = 0;
  }
}

sub align {
  my $self = shift;
  my $alignment = shift || 'L';
  
  if ($alignment eq 'R') {
    $self->append( chr(27)."a".chr(50) );
  } elsif ($alignment eq 'C') {   
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

  my $feed = $self->kbyte($lines);

  $self->append( $self->kbyte(29) . "V". $self->kbyte(65) . $feed );
}

sub output {
  my $self = shift;
  
  my $fh = $self->handle();
  
  print $fh $self->document();

  $self->document(''); 
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

sub kbyte {
  my $self = shift;
  my $val = shift;

  return pack('C', $val);
}

1;
