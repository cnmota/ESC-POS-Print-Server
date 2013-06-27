package Printer::Remote;

use HTTP::Request;
use LWP::UserAgent;
use JSON::XS;

use Moo::Role;

has coder => (
  is => 'rw',
  required => 0,
  default => sub { return JSON::XS->new->ascii }
);

sub __conn__ {
  my $self = shift;
  my $method = shift;
  my $url = shift;                                     
  my $data = shift;
       
  my $req = HTTP::Request->new($method => $url);

  $req->content_type('application/json'); 
  $req->content( $self->coder->encode( $data ) );

  my $res = LWP::UserAgent->new()->request($req);
                   
  return $res;       
}

sub get_data {
  my $self = shift;
  my $url = shift;
  my $data = shift;
  
  my $res = $self->__conn__( 'GET', $url, $data );
  my $status = $res->code() eq '200' ? 1 : 0;

  return $res;
}

sub post_data {
  my $self = shift;
  my $url = shift;
  my $data = shift;

  my $res = $self->__conn__( 'POST', $url, $data );
  my $status = $res->code() eq '200' ? 1 : 0;

  return $res;
}

1;