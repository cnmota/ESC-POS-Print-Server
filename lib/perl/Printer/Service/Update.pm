package Printer::Service::Update;

use Moo;
use HTTP::Request;
use LWP::UserAgent;
use JSON::XS;

has config => (
  is => 'rw',
  required => 1,
);

has interval_time => (
  is => 'rw',
  required => 0,
  default => sub {
    my $self = shift;                                                 
                                                                    
    my $interval_time = $self->{config}->{update_interval} || 300;
    $interval_time = 300 if ($interval_time < 300);
                      
    $interval_time = 10; 
    return $interval_time;
  }
);

has data_dir => (
  is => 'rw',
  required => 0,
  default => sub {
    my $self = shift;
    
    return $self->{config}->{app_dir}.'/data/';
  }
);
    
sub run {
  my $self = shift;                 
  
  while (1) {
    $self->check();
    
    sleep $self->interval_time();
  }
}

sub check {
  my $self = shift;
  
  my $req = HTTP::Request->new('GET' => $self->{config}->{url} . $self->{config}->{uuid});
  $req->content_type('application/json');
  
  my $res = LWP::UserAgent->new()->request($req);
  
  if ($res->code() eq '200') {
    my $raw_data = $res->content();
    my $parsed_data = decode_json $res->content();
    
    #CHECK IF FILE EXISTS
    my $file = $self->data_dir().'/cache/current';
    my $write = 0;
  
    if (-e $file) {
      my $mtime = (stat $file)[9];
      
      print STDERR $parsed_data->{updated_at}." > ".$mtime."\n"; 
      
      $write = 1 if ($parsed_data->{updated_at} > $mtime);
    } else {
      $write = 1;
    }  
    
    if ($write) {
      print STDERR "WRITING NEW DATA\n";
      
      open my $fh, ">", $file;
      print $fh $raw_data;
      close $fh;

      foreach my $c_id (keys %{ $parsed_data->{data} || {}}) {
        my $campaign = $parsed_data->{data}->{$c_id};
        foreach my $asset ( @{ $campaign->{assets} } ) {
          my $filename = split(/\//, $asset); undef;
          print STDERR "$asset\n";
          system( "cd ".$self->data_dir()."/cache/assets; wget -q -N $asset" );
        }
      }
    }


  }
}

1;
