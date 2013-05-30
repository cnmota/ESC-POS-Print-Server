use ESCPOS::Printer::Image;

use lib qw( /mnt/shared/Printer-TM );

my $d = '24SD';
my $fname = "/mnt/shared/Printer-TM/source/cata.jpg";

my $img = ESCPOS::Printer::Image->new( density => $d, path => $fname, dither_method => 'Atkinson' );
my $img = ESCPOS::Printer::Image->new( density => $d, path => $fname, dither_method => 'Floyd' );
