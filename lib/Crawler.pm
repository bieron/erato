package Crawler;
use Moose;
use LWP;
use Data::Dumper;
#use HTTP::Cookies;

has 'address' => (is => 'rw', isa => 'Str', trigger => \&correctUrl);
has 'get' => (is => 'rw', isa => 'HashRef', default => sub {{}});
has 'post' => (is => 'rw', isa => 'HashRef', default => sub {{}});
has 'url' => (is => 'rw', isa => 'Str');
      has 'row' => (is => 'rw', isa => 'Str');


has 'html' => (is => 'rw', isa => 'Str');
has 'cache' => (is => 'ro', isa => 'Str', default => 'cache');
has 'parser' => (is => 'rw', isa => 'Ref');

my%fnames;

sub crawl {
   my$self = shift;
   warn 'wtf' unless $self->html;
   my($html,$row) = ($self->html, $self->row);
   my$fun = $self->parser;
   my@parsed = $fun->($self);
   my@shows = (); $#shows = $#parsed;
   for(my$i=0; $i<$#parsed; ++$i) {
      $shows[$i] = new Show( $parsed[$i] );#passes hashref
   }
=begin      
      for my$a (@parsed) {

      warn Data::Dumper->Dump( [\$a], ['a'] );
   }
   while($html =~ m/$row/gx) {
      print $1,$2,$3,$4,$5;
   my@matches = $html =~ m/$row/gx;
   for my$a (@matches) {
      print 'row';
      print $a;
      warn Data::Dumper->Dump([\$a], ['a']);
   }
=cut
}

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
   my$html = $rsvp->content;
   $html =~ s/\n//g;
   $html =~ s/\s+/ /g;

#   print $self->address;
#   print $fn;
   
   $self->html( $html );
   open $f, '>', $fn;
   print $f $html;
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
