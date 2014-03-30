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

sub dow {#class helper
   my$dow = lc substr(shift,0,3);
   $dow = 'wt' if $dow eq 'wto';
   $dow = 'pt' if $dow =~ /pi./;
   $dow = 'sb' if $dow eq 'sob';
   $dow = 'nd' if $dow eq 'nie';
   $dow;
}
sub sortKeys {
#   my$self = shift;
   my%data = %{ shift() };
   my@ks = sort {
      $data{$a}->{dates}[0][0] cmp $data{$b}->{dates}[0][0] 
   } keys %data;
   @ks;
#   for(@ks) { print $data{$_}->{dates}[0][0] }
}

sub limit {
   my%d = @_;
   my%data = %{$d{data}};
   delete $d{data};
   my@limits = @{ $d{(keys %d)[0]} };
   if ($d{and}) {
      for my$k (keys %data) {
         for my$t ( @{$data{$k}->{dates}} ) {
            for my$l (@limits) {
               print $k, @$t, $l;
            }
         }
      }
   } elsif ($d{or}) {
   
   }
   print @limits;
}

sub crawl {
   my$self = shift;
   warn 'wtf' unless $self->html;
   my($html,$row) = ($self->html, $self->row);
   my$fun = $self->parser;
   my@parsed = $fun->($self);
#   warn Data::Dumper->Dump( [@parsed] );
#   exit;
   my%data;
   for my$row (@parsed) {
#TODO tidy title, dow, hour. tidy other values if first time
# then send to Show constructor
      my%row = %{$row};
      #my$key = $row{title};
      my$key = $row{url};
#      $key = ucfirst lc $key;
      $row{dow} = dow($row{dow});
#      $row{hour} =~ s/<[^>]+>/,/g;
#      $row{hour} =~ s/,+\s*$//;
#      $row{hour} =~ s/,+/, /g;
      
      my@when = ($row{date},$row{dow},$row{hour});
      if($data{$key}) {
         push @{$data{$key}->{dates}}, \@when;
         next;
      }
#      delete $row{title}; delete $row{date}; delete $row{hour}; delete $row{dow};
      delete $row{date}; delete $row{hour}; delete $row{dow};
      $row{dates} = [ \@when ];
      $data{$key} = \%row;
   }
   my@shows;
   while( my($a,$b) = each %data) {
#      $b->{title} = $a;
#      $b->{url} = $a;
      push @shows, Show->new($b);
#      print $b->{title}, keys %{$b},"\n";
   }
   for (@shows) {
   }
   #warn Data::Dumper->Dump( [%data] );
   my@ks = sortKeys( \%data );
   print scalar keys %data;
#   print %{$data{key}};
   limit( data => \%data, and => [2]);
   print scalar keys %data;

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
      print 'http response ', $code;
   }
   my$html = $rsvp->content;
   ($html) = $html =~ /(<body.*body>)/s;
   $html =~ s/<script.*?script>//sg;
   $html =~ s/\n//g;
   $html =~ s/&nbsp;/ /g;
   $html =~ s/&ndash;/-/g;
   $html =~ s/&oacute;/ó/g;
   $html =~ s/&quot;/"/g;
   $html =~ s/\s+/ /g;
#   print length $html;

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
