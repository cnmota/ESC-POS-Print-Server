package Printer::Service::Print;

use bytes;
use Encode::Byte;
use Encode qw(encode decode);

use Moo;

use IO::Socket;
use IO::Select;

use JSON::XS;
use HTML::TreeBuilder;

use ESCPOS::Printer;

has config => (
  is => 'rw',
  required => 1,
);

has printer => (                                   
  is => 'rw',                                      
  required => 0,                                   
);

sub BUILD {
  my $self = shift;

  $self->printer( 
    ESCPOS::Printer->new( device => ESCPOS::Printer::Device->new( port => '/dev/tts/USB0' ) )
  );   
}

sub run {
  my $self = shift;                 
  
  my $server_socket = IO::Socket::INET->new(
    Proto     => 'tcp',              
    LocalHost => $self->{config}->{host} || '127.0.0.1', 
    LocalPort => $self->{config}->{port} || 3000,
    Proto => 'tcp',                  
    Listen => 5,                     
    Reuse => 1                       
  ) or die "$@";                     
                                     
  my $sel = IO::Select->new();
  $sel->add($server_socket) or die "IO::Select $!"; 
  
  my $data = "";

  while (1) {
    my $has_new_data = 0;
    my @ready = $sel->can_read(0.5);
    
    foreach my $client (@ready) {
      if ($client == $server_socket) {
        my $new = $server_socket->accept;
        $sel->add( $new );
        warn "[event socket] connect from ",$new->peerhost, "\n";
      } else {
        if ( my $read = sysread($client, my $buff, 512) ) {
          $data .= $buff;
          $has_new_data = 1;
        }
      }
    }
    
    if (!$has_new_data && $data) {
      print STDERR "#PRINT DATA\n";
      $self->handle_request( $data );
      $data = "";
    }
  }
}

sub handle_request {
  my $self = shift;
  my $data = shift;
  
  $self->printer()->text($data);
  
  my $campaign = $self->get_current_campaign();
  
  if (defined $campaign) {
    $self->add_footer( campaign => $campaign, doc_number => $self->get_doc_number( $data ) );
  }
  
  $self->printer()->print();
};

sub get_current_campaign {
  my $self = shift;
  
  $self->refresh_cache();
  
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  
  #FIX wday
  $wday = 7 unless $wday;
  
  foreach my $campaign_id (keys %{$self->{__cache__}->{data} || {}}) {
    my $campaign = $self->{__cache__}->{data}->{$campaign_id};
    $campaign->{id} = $campaign_id;
    
    if ( defined $campaign->{weekday} && int($campaign->{weekday}) == int($wday) ) {
      if (defined $campaign->{schedule} && scalar(@{ $campaign->{schedule} }) ) {
        foreach my $shour (@{ $campaign->{schedule} || [] }) {
          if ( int($hour) == int($shour) ) {
            return $campaign;
          }
        }
      }
    }
  }
  
  return undef;
}

sub refresh_cache {
  my $self = shift;
  
  my $file = $self->{config}->{app_dir}.'/data/cache/current';
  
  if (-e $file) { 
    open my $fh, "<", $file;
    my $raw_data = do {local $/;<$fh>};
    close $fh;
    
    $self->{__cache__} = decode_json $raw_data;
  } else {
    $self->{__cache__} = {};
  }
}

sub get_doc_number {
  my $self = shift;
  my $text = shift;
  
  foreach my $line (split(/\n/,$text)) {
    $line =~ s/\r//g;
    if ($line =~ /(\d+\/\d+)\s+\d+\/\d+\/\d+/g) {
      return $1;
    }
  } 
}

sub add_footer {
  my $self = shift;
  my %params = @_;
  
  my $campaign = $params{campaign};
  
  if (defined $campaign && defined $params{doc_number} && $params{doc_number}) {
#    $self->printer()->text( chr(27).chr(116).chr(3) );
    if (!defined $campaign->{do_cut}) {
      #remove cut from current buffer;
      $self->printer()->search_replace( $self->printer()->cmd_seq_cut(), '' );
      $self->printer()->search_replace( $self->printer()->cmd_seq_pcut(), '' );
      $self->printer()->search_replace( $self->printer()->cmd_seq_linefeed() . '.' , '' );
    } 
    
    $campaign->{content} = encode("cp860", $campaign->{content});
    my $tree = HTML::TreeBuilder->new(); 
    my $root = $tree->parse_content( $campaign->{content} ); 

    $self->dom_to_print(element => $root);
    
    $self->printer()->linefeed();
    $self->printer()->align('C');
    $self->printer()->text($params{doc_number}) if (defined $params{doc_number});
    $self->printer()->linefeed();
    $self->printer()->cut();
  } else { 
    $self->{__cache__} = { data => {} };
  }
}

sub dom_to_print {
  my $self = shift;
  my %params = @_;

  my $element = $params{element};
  
  if (ref($element) =~ /HTML\:\:/) {
    $self->dom_to_print_tag(tag => $element->tag(), mode => 'start', element => $element);
     
    foreach my $child (@{ $element->content_array_ref() || []}) {             
      $self->dom_to_print(element => $child);
    }   
    
    $self->dom_to_print_tag(tag => $element->tag(), mode => 'end');
  } else {
    $self->printer()->text($element);
  }
}

sub dom_to_print_tag {
  my $self = shift;
  my %params = @_;
 
  if ($params{tag} eq 'u') {
    if ($params{mode} eq 'start') {
      $self->printer()->underline(1);
    } else {
      $self->printer()->underline(0);
    }
  }
  
  if ($params{tag} eq 'strong') {              
    if ($params{mode} eq 'start') {                        
       $self->printer()->bold(1);
    } else {                              
       $self->printer()->bold(0);
    }                                     
  }  
  
  if ($params{tag} eq 'p') {
    if ($params{mode} eq 'start') {
      my $align = 'L';
      
      $align = 'C' if (defined $params{element}->attr('align') && $params{element}->attr('align') eq 'center'); 
      $self->printer()->align($align);   
    } else {                        
      $self->printer()->linefeed();
      $self->printer()->align('L');
    } 
  }
  
  if ($params{tag} eq 'br' && $params{mode} eq 'start') {
    $self->printer()->linefeed();
  }

  if ($params{tag} eq 'object' && $params{mode} eq 'start') {
    if ( defined $params{element}->attr('src') ) {
      my $src = $params{element}->attr('src');
      $self->printer()->align('C');
      $self->printer()->qrcode( $src );
      $self->printer()->linefeed();
      $self->printer()->align('L');
    }
  }
  
  if ($params{tag} eq 'img' && defined $params{element}) {
    if (defined $params{element}->attr('src') ) {
      my $file = $params{element}->attr('src');
    
      if (-e $self->config()->{app_dir}.'/data/cache/assets/'.$file) {
  #      $self->printer()->linefeed();
  #      $self->printer()->image( $self->config()->{app_dir}.'/data/cache/assets/'.$file, '24DD' ); 
      }
    }
  }
}

1;
