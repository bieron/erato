package Crawler;
use Moose;
use LWP;
#use HTTP::Cookies;

has 'address' => (is => 'rw', isa => 'Str', trigger => \&correctUrl);
has 'get' => (is => 'rw', isa => 'HashRef', default => sub {{}});
has 'post' => (is => 'rw', isa => 'HashRef', default => sub {{}});
has 'url' => (is => 'rw', isa => 'Str');


has 'html' => (is => 'rw', isa => 'Str');
has 'cache' => (is => 'ro', isa => 'Str', default => 'cache');

my%fnames;

sub correctUrl {
   my($self,$u) = @_;
   unless(  $u =~ m@^(f|ht)tp://@ ) {
      $self->address( 'http://' . $u );#thankfully doesn't call trigger again
   }
#   $self->url( $self->address );
}

sub recent {#class function
   time - shift() < 3600;#okres waznosci 1h
}

sub BUILD {
   my$self = shift;
   mkdir $self->cache if !-e $self->cache;   #TODO cwd first!
}

sub getName {
   my$self = shift;
   my$u = $self->url;
   return $fnames{$u} if($fnames{$u});
   my$fn = $u;
   $fn =~ s@[:/]@_@g;
   $fnames{$u} = $self->cache .'/'. $fn;   #TODO generic os path separator
}

sub querystring {#class function
   my%h = %{shift()};
   my$qs = '';
   for my$k (keys %h) {
      $qs .= $k .'='. $h{$k} .'&';
   }
   $qs;
}

my$ua = LWP::UserAgent->new;
$ua->agent('Mozilla/8.0');

before 'fetch' => sub {
   my($self,$a) = @_;
   $self->address($a) if $a;
   my$u = $self->address;
   if($u) {
      $u .= '?' . querystring($self->get);
      $self->url($u);
   }
};

sub fetch {
   my$self = shift;

   my$fn = $self->getName;

   open my$f, '<', $fn or goto NOCACHE;
   my$mt = (stat($f))[10];
   goto NOCACHE if not recent $mt;
   {  local $/; $self->html( <$f> ) }
   close $f;
   return 666;

   NOCACHE:
   my$rsvp;
  
   if( %{$self->post} ) {
      $rsvp = HTTP::Request->new(POST => $self->address);
      $rsvp->content( querystring($self->post) );
   } else {
      $rsvp = HTTP::Request->new(GET => $self->address);
   }
   $rsvp = $ua->request($rsvp);
   my$code = $rsvp->code;
   if($code < 200 || $code  > 299) {
      print 'yo mister white';
   }
   $self->html( $rsvp->content);
#   print $self->address;
#   print $fn;
   
   open $f, '>', $fn;
   print $f $self->html;
   close $f;

   return $code;
}
sub addGet {
   my$self = shift;
#   my%nv = @_;
   my%g = %{$self->get};
   %g = ( %g, @_);
   $self->get( %g );
   print %{$self->get};
}

__PACKAGE__->meta->make_immutable;
1;

=begin
package Fetcher;
use Moose;
extends 'Crawler';

has 'month' => (is => 'rw', isa => 'Str');
has 'year' => (is => 'rw', isa => 'Str');

my($m, $y);#next month, next month's year

sub BUILD {
   ($m,$y) = (localtime)[4,5];
   $m += 2, $y += 1900;
   if($m == 13) {
      $m = 1, ++$y;
   }
}


before 'fetch' => sub {
   my$self = shift;
   if($self->month) {
      if($self->post) {
      } else {
         print 'co';
         $self->addGet( $self->month => $m );
      }
   }
   if($self->year) {
      if($self->post) {
      } else {
         $self->addGet( $self->year => $y );
      }
   }
};

__PACKAGE__->meta->make_immutable;
1;
=cut   
