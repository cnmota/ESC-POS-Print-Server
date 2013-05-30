package Printer::Server;

use Moo;
use Config::INI::Reader;

use Printer::Service::Print;
use Printer::Service::Update;

#PUBLIC METHODS

has config => (
  is => 'rw',
  required => 0,
);

#PRIVATE METHODS 

sub BUILD {
  my $self = shift;
  
  $self->config( Config::INI::Reader->read_file( '/opt/Print-Server/etc/config.ini' )->{'_'} );
}

sub run {
  my $self = shift;
  
  mkdir $self->config()->{app_dir}.'/data' unless -e $self->config()->{app_dir}.'/data';
  mkdir $self->config()->{app_dir}.'/data/cache/' unless -e $self->config()->{app_dir}.'/data/cache';
  mkdir $self->config()->{app_dir}.'/data/cache/assets' unless -e $self->config()->{app_dir}.'/data/cache/assets'; 
  
  my $pid = fork();
 
  while (1) { 
    if ($pid) {
      #PARENT PROCESS
      print STDERR "STARTING UPDATE SERVICE...\n";
      Printer::Service::Update->new( config => $self->config() )->run();
    } else {
      #CHILD PROCESS
      print STDERR "STARTING PRINT SERVICE...\n";
      Printer::Service::Print->new( config => $self->config() )->run();  
    }
  }
}

1;
