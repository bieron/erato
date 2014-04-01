package Crawler;
use Moose;
use LWP;
use Data::Dumper;
#use HTML::TableExtract;#load
use Text::Table;       #load
use Mojo::DOM;
use DBI;
use DBD::Pg;
#use HTML::Parser;
use HTTP::Cookies;


has 'address' => (is => 'rw', isa => 'Str', trigger => \&correctUrl);
has 'get' => (is => 'rw', isa => 'HashRef', default => sub {{}});
has 'post' => (is => 'rw', isa => 'HashRef', default => sub {{}});
has 'url' => (is => 'rw', isa => 'Str');
has 'row' => (is => 'rw', isa => 'Str');
has 'html' => (is => 'rw', isa => 'Str');
has 'cache' => (is => 'ro', isa => 'Str', default => 'cache');
has 'parser' => (is => 'rw', isa => 'Ref');
has 'shows' => (is => 'rw', isa=>'HashRef', default => sub {{}});
has 'what' => (is => 'rw', isa=>'Str');

my@date = (localtime)[5,4];
my$year = $date[0] + 1900;
my$month = ($date[1]+2)%13;

my%fnames;
my$ua = LWP::UserAgent->new;
$ua->agent('Mozilla/8.0');
$ua->cookie_jar( HTTP::Cookies->new(
	file => 'erato.lwp', autosave => 1
));

#sub dow {#class helper
#   my$dow = lc substr(shift,0,3);
#	$dow = 'wt' if $dow eq 'wto';
#   $dow = 'pt' if $dow =~ /pi./;
#	$dow = 'sb' if $dow eq 'sob';
#	$dow = 'nd' if $dow eq 'nie';
#   $dow;
#}

sub recent {#class function
   time - shift() < 3600;#okres waznosci 1h
}
#sub getUrl {
#	my%a = @_;
#	my%url_of = (
#		slowacki_duza =>	'http://slowacki.krakow.pl/pl/repertuar/duza_scena/_get/month/!m/year/!y',
#		slowacki_mala =>	'http://slowacki.krakow.pl/pl/repertuar/scena_miniatura/_get/month/!m/year/!y',
#		filharmonia => 	'www.filharmonia.krakow.pl/Repertuar/Kalendarium/?events=process&date=month&month=!m&year=!y',
#		opera =>				'opera'
#	);
#	my$u =  $url_of{ $a{what} };
#	$u =~ s/!m/$a{month}/;
#	$u =~ s/!y/$a{year}/;
#	return $u;
#}
#sub sortKeys {
##   my$self = shift;
#   my%data = %{ shift() };
#   my@ks = sort {
#      $data{$a}->{dates}[0][0] cmp $data{$b}->{dates}[0][0]
#   } keys %data;
#   @ks;
##   for(@ks) { print $data{$_}->{dates}[0][0] }
#}
#
#sub limit {
#   my%d = @_;
#   my%data = %{$d{data}};
#   delete $d{data};
#   my@limits = @{ $d{(keys %d)[0]} };
#   if ($d{and}) {
#      for my$k (keys %data) {
#         for my$t ( @{$data{$k}->{dates}} ) {
#            for my$l (@limits) {
#               print $k, @$t, $l;
#            }
#         }
#      }
#   } elsif ($d{or}) {
#
#   }
#   print @limits;
#}

sub fetch {
	my$self = shift;
	$self->read(@_);
	$self->parse;
	$self->save;
}
sub read {
   my$self = shift;
	my%a = @_;
	$self->what($a{what});
	$a{month} ||= $month;
	$a{year}  ||= $year;
#	$self->address( getUrl( %a ) );

#print $self->url;
#	my$fn = $self->getName;
	my$fn = 'cache/' . $year.'-'.$month.'-'.$self->what .'.html';

	goto NOCACHE;
	open my$f, '<', $fn or goto NOCACHE;
	my$mt = (stat($f))[10];
	goto NOCACHE if not recent $mt;
	{  local $/; $self->html( <$f> ) }
	close $f;
	return 666;

	NOCACHE:
	my$rsvp;

	if ($self->what =~ /stary/) {
		my%url_of = (
	 	 	stary_duza =>		'stary.pl/pl/repertuar/1',
	  		stary_mala =>		'stary.pl/pl/repertuar/2',
		);
		$rsvp = HTTP::Request->new(POST => $url_of{ $self->what });

		my$post = 'dateFrom='.$year.'-'.$month.'-01&dateTo='.$year.'-'.$month
						 			.'-31&idSpectacle=&show=Poka%C5%BC';

		$rsvp->content( $post );
	} else {
		my%url_of = (
			slowacki_duza =>	'http://slowacki.krakow.pl/pl/repertuar/duza_scena/_get/month/!m/year/!y',
			slowacki_mala =>	'http://slowacki.krakow.pl/pl/repertuar/scena_miniatura/_get/month/!m/year/!y',
			filharmonia => 	'http://www.filharmonia.krakow.pl/Repertuar/Kalendarium/?events=process&date=month&month=!m&year=!y',
			opera	=>				'http://opera.krakow.pl/pl/repertuar/na-afiszu/!m',
			bagatela =>			'http://www.bagatela.pl/Repertuar/?repertoire=repertoire&view_date=!y-!m'
		);
		my$url = $url_of{ $self->what };
		$url =~ s/!m/$month/;
		$url =~ s/!y/$year/;
		#print $url and die;
		$rsvp = HTTP::Request->new(GET => $url_of{ $self->what });
	}
	$rsvp = $ua->request($rsvp);
	my$code = $rsvp->code;
	if($code < 200 || $code  > 299) {
		print 'http response ', $code;
	}
	my$html = $rsvp->decoded_content ;
	my($body) = $html =~ m/(<body.*body>)/s;
	$body =~ s/<script.*?script>//sg;
#	$body =~ s/\n//g;
#	$body =~ s/&nbsp;/ /g;
#	$body =~ s/&ndash;/-/g;
#	$body =~ s/&oacute;/ó/g;
#	$body =~ s/&quot;/"/g;
#	$body =~ s/\s+/ /g;
	my($title) = ($html =~ m/(<title.*?title>)/);
	$html = '<html><head>'.$title.'</head>'.$body.'</html>' ;

#	print $body and die('body');

	open $f, '>', $fn or die('cant');
	print $f $html;
	close $f;

	$self->html( $html);
	return $code;
}

sub parse {
	my$self = shift;

	my$dom = Mojo::DOM->new($self->html);

	#print $self->html and die;

   my%shows;
	for my$r ($dom->at('#tableCalendary')->children->each) {
		my($dom) 	= $r =~ />\s*			([0123]?\d)		\s*</x;
#		my($dow) 	= $r =~ /td0a">\s*	(\w+)				/x;
		my($url) 	= $r =~ /href="		([^"]+)			"/x;
		my($title) 	= $r =~ /<a[^>]+>\s*	(.*?)				\s*<\/a/x;
		my($hour) 	= $r =~ />\s*			(\d{1,2}:\d\d)	\s*</x;

		#next unless( defined $dom && defined $dow && defined $url &&
		next unless( defined $dom && defined $url &&
						 defined $title && defined $hour);

		$shows{$url} = [$title, []] if not $shows{$url};

		push @{ $shows{$url}->[1] }, "$year-$month-$dom $hour";
	}
	$self->shows( \%shows );
}
sub save {
	my$self = shift;
	my$dbh = DBI->connect("dbi:Pg:dbname=erato", "", "");
	my%ss = %{$self->shows};
	#print Dumper(%ss);

	my%places = (
		'slowacki_duza' => 'Słowacki - Duża Scena',
		'slowacki_mala' => 'Słowacki - Scena Kameralna',
		'stary_duza'	 => 'Stary - Duża Scena',
		'stary_mala'	 => 'Stary - Scena Miniatura',
		'filharmonia'	 => 'Filharmonia',
		'bagatela'		 => 'Bagatela'
	);

   for my$url (keys %ss) {
		$dbh->do('INSERT INTO shows VALUES (?,?,?)', undef,
					$url, $ss{$url}->[0], $places{ $self->what });
		for my$date (@{$ss{$url}->[1]}) {
			$dbh->do('INSERT INTO dates VALUES (?,?)',undef,
						$url, $date);
		}
	}

}
sub prepare {
   my($self,$html) = @_;
}
sub view {
	print 'view'

	}

sub correctUrl {
   my($self,$u) = @_;
   unless(  $u =~ m@^(f|ht)tp://@ ) {
      $self->address( 'http://' . $u );#thankfully doesn't call trigger again
   }
}


sub BUILD {
   my$self = shift;
   mkdir $self->cache if !-e $self->cache;   #TODO cwd first!
}

sub getName {
   my$self = shift;
   my$u = $self->address;
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


#before 'fetch' => sub {
#   my($self,$a) = @_;
#   $self->address($a) if $a;
#   my$u = $self->address;
#   if($u) {
#      $u .= '?' . querystring($self->get);
#      $self->url($u);
#   }
#};

#sub fetch {
#   my$self = shift;
#
#   my$fn = $self->getName;
#
#   open my$f, '<', $fn or goto NOCACHE;
#   my$mt = (stat($f))[10];
#   goto NOCACHE if not recent $mt;
#   {  local $/; $self->html( <$f> ) }
#   close $f;
#   return 666;
#
#   NOCACHE:
#   my$rsvp;
#
#   if( %{$self->post} ) {
#      $rsvp = HTTP::Request->new(POST => $self->address);
#      $rsvp->content( querystring($self->post) );
#   } else {
#      $rsvp = HTTP::Request->new(GET => $self->address);
#   }
#   $rsvp = $ua->request($rsvp);
#   my$code = $rsvp->code;
#   if($code < 200 || $code  > 299) {
#      print 'http response ', $code;
#   }
#   my$html = $rsvp->content;
#   ($html) = $html =~ /(<body.*body>)/s;
#   $html =~ s/<script.*?script>//sg;
#   $html =~ s/\n//g;
#   $html =~ s/&nbsp;/ /g;
#   $html =~ s/&ndash;/-/g;
#   $html =~ s/&oacute;/ó/g;
#   $html =~ s/&quot;/"/g;
#   $html =~ s/\s+/ /g;
##   print length $html;
#
#   $self->html( $html );
#   open $f, '>', $fn;
#   print $f $html;
#   close $f;
#
#   return $code;
#}

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
