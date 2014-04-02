package Crawler;
use Moose;
use LWP;
use Data::Dumper;
use Mojo::DOM;
use HTTP::Cookies;
use utf8;
use open qw/:std :utf8/;

my$DEBUG = 1;
sub d($) { print STDERR shift }
sub D($) { print Dumper(@_)}

my@date = (localtime)[5,4];
my$year = $date[0] + 1900;
my$month = ($date[1]+2)%13;

has 'url' => (is => 'rw', isa => 'Str');
has 'html' => (is => 'rw', isa => 'Str');
has 'cache' => (is => 'ro', isa => 'Str', default => 'cache');
has 'parser' => (is => 'rw', isa => 'Ref');
has 'shows' => (is => 'rw', isa=>'HashRef', default => sub {{}});
has 'what' => (is => 'rw', isa=>'Str');

my%fnames;
my$ua = LWP::UserAgent->new;
$ua->agent('Mozilla/8.0');
$ua->cookie_jar( HTTP::Cookies->new(
	file => 'erato.lwp', autosave => 1
));

sub recent {#class function
   time - shift() < 3600;#okres waznosci 1h
}
sub fetch {
	my$self = shift;
	d 'read '.$_[1];
	$self->read(@_);
	d 'parse '.$self->what;
	return $self->parse;
}
sub read {
   my$self = shift;
	my%a = @_;
	$self->what($a{what});
	$a{month} ||= $month;
	$a{year}  ||= $year;

	my($place) = $self->what =~ /([^-]+)/;
	my$fn = "cache/$year-$month-$place.html";

#	goto NOCACHE;
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
	 	 	stary_duza =>		'http://www.stary.pl/pl/repertuar/1',
	  		stary_mala =>		'http://www.stary.pl/pl/repertuar/2',
		);
		$rsvp = HTTP::Request->new(POST => $url_of{ $self->what });
		my$post = 'dateFrom='.$year.'-'.$month.'-01&dateTo='.$year.'-'.$month
						 			.'-31&idSpectacle=&show=Poka%C5%BC';
		$rsvp->content( $post );
	} elsif ($self->what eq 'opera') {
		my@ms = qw/styczen luty marzec kwiecien maj czerwiec lipiec sierpien wrzesien pazdziernik listopad grudzien/;
		$rsvp = HTTP::Request->new(GET => 'http://opera.krakow.pl/pl/repertuar/na-afiszu/' . $ms[ $month-1 ] );
	} else {
		my%url_of = (
			slowacki_duza 			=>	'http://slowacki.krakow.pl/pl/repertuar/duza_scena/_get/month/!m/year/!y',
			slowacki_mala 			=>	'http://slowacki.krakow.pl/pl/repertuar/scena_miniatura/_get/month/!m/year/!y',
			filharmonia 			=>	'http://www.filharmonia.krakow.pl/Repertuar/Kalendarium/?events=process&date=month&month=!m&year=!y',
			'bagatela-sarego' 	=> 'http://www.bagatela.pl/Repertuar/?repertoire=repertoire&view_date=!y-!m',
			'bagatela-karmelicka'=>	'http://www.bagatela.pl/Repertuar/?repertoire=repertoire&view_date=!y-!m'
		);
		my$url = $url_of{ $self->what };
		$url =~ s/!m/$month/;
		$url =~ s/!y/$year/;
		$rsvp = HTTP::Request->new(GET => $url );
	}
	$rsvp = $ua->request($rsvp);
	my$code = $rsvp->code;
	if($code < 200 || $code  > 299) {
		print Dumper($rsvp->request);
		open my$f, '>', "cache/$year-$month-$code.html"; print $f $rsvp->decoded_content; close $f;
		die 'got '.$code;# from .$rsvp->request;
	}
	#print Dumper($rsvp->request) and die;
	my$html = $rsvp->decoded_content ;
	my($body) = $html =~ m/(<body.*body>)/s;
	$body =~ s/<script.*?script>//sg;
	$body =~ s/<br\s*\/?>//g;
	$body =~ s/\s*\n\s*/\n/g;
#	$body =~ s/\n\n+/\n/g;
	$body =~ s/[\t ]+/ /g;
	my($title) = ($html =~ m/(<title.*?title>)/);
	$html = '<html><head>'.$title.'</head>'.$body.'</html>' ;

#	print $body and die('body');
	open $f, '>', $fn or warn "can't write to file $fn";
	print $f $html;
	close $f;

	$self->html( $html);
	return $code;
}

my%parsers = (
	slowacki => sub {
		my$self=shift; my%shows;
		my$dom = Mojo::DOM->new($self->html);

		for my$r ($dom->at('#tableCalendary')->children->each) {
			my($img,$desc) = (' ',' ');#unobligatory
			my($dom) 		= $r =~ />\s*			([0123]?\d)		\s*</x;
			my($url) 		= $r =~ /href="		([^"]+)			"/x;
			my($title) 		= $r =~ /<a[^>]+>\s*	(.*?)				\s*<\/a/x;
			my($hour) 		= $r =~ />\s*			(\d{1,2}:\d\d)	\s*</x;

			next unless( defined $dom && defined $url && defined $title && defined $hour);
			$shows{$url} = {title=> $title, dates=>[], desc=>$desc, img=>$img} if not $shows{$url};
			push @{ $shows{$url}->{dates} }, "$year-$month-$dom $hour";
		}
		return \%shows;
	},
	stary => sub {
		my$self=shift; my%shows;
		my$dom = Mojo::DOM->new($self->html);

		for my$r ($dom->find('.mainFrameNews')->each) {
			my($img) 	= $r =~ /src=".?([^"]+)/;
			my$desc		= $r->find('.mainFrameNewsDesc');#->all_text;
			my$title		= $desc->at('a')->text;
			$title 		= "$title";
			$desc 		= $desc->all_text;
			$desc 		= "$desc"; #Mojo::Collection stringify method overload
			my($hour)	= $r =~ /(\d\d:\d\d)/;
			my($url) 	= $r =~ /href="		(.+?spektakl[^"]+)  /x;
			my($date)	= $r->previous_sibling->previous_sibling =~ /([\d-]{8,10})/;

			next unless( defined $date && defined $url && defined $title && defined $hour);
			$shows{$url} = {title=> $title, dates=>[], desc=>$desc, img=>$img} if not $shows{$url};
			push @{ $shows{$url}->{dates} }, "$date $hour";
		}
		return \%shows;
	},
	filharmonia => sub {
		my$self=shift; my%shows;
		my$dom = Mojo::DOM->new($self->html);

		for my$r ($dom->find('.event')->each) {
			my($img) 	= $r->at('.thunbail') =~ /src=".?([^"]+)/;
			my$title		= $r->at('h1')->a->text;
			next if (!defined $title || $title =~ /DZIECI/);#to mnie nie interesuje
			my$desc 		= $r->find('p')->all_text();
			$desc   		= "$desc"; #Mojo::Collection stringify method overload
			my$hour 		= $r->at('.hour')->text;
			my($url)   	= $r =~ /href="		 ([^"]+)	  /x;
			my($date)  	= $r =~ /dataday">\s* ([\d-]+)	/x;

			next unless( defined $date && defined $url && defined $title && defined $hour);#obligatory
			$shows{$url} = {title=> $title, dates=>[], desc=>$desc, img=>$img} if not $shows{$url};
			push @{ $shows{$url}->{dates} }, "$date $hour";
		}
		return \%shows;
	},
	'bagatela-karmelicka' => sub {
		my$self=shift; my%shows;
		my$dom = Mojo::DOM->new($self->html);

		for my$r ($dom->find('.not-empty-a')->each) {
			my($img,$desc) = (' ',' ');#unobligatory
			my$url 		= $r->at('.name-a')->a->attr('href');
			my$title 	= $r->at('.name-a')->a->text;
			my$hour 		= $r->at('.hour-a')->all_text;
			$hour 		=~ s/ /:/;
			my$day = $r->at('.day-a');
			if ($day) {
				($day) 	= $day->text =~ /(\d+)/;
			} else {
				$day = $r->previous_sibling->previous_sibling->at('.day-a')->text =~ /(\d+)/;
			}

			next unless( defined $day && defined $url && defined $title && defined $hour);#obligatory
			$shows{$url} = {title=> $title, dates=>[], desc=>$desc, img=>$img} if not $shows{$url};
			push @{ $shows{$url}->{dates} }, $year.'-'.$month."-$day $hour";
		}
		return \%shows;
	},
	'bagatela-sarego' => sub {
		my$self=shift; my%shows;
		my$dom = Mojo::DOM->new($self->html);

		for my$r ($dom->find('.not-empty-b')->each) {#tu sie rozni
			my($img,$desc) = (' ',' ');#unobligatory
			my$url 	= $r->at('.name-b')->a->attr('href');
			my$title = $r->at('.name-b')->a->text;
			my$hour 	= $r->at('.hour-b')->all_text;
			$hour 	=~ s/ /:/;
			my$day 	= $r->at('.day-b');
			if ($day) {
				($day) 	= $day->text =~ /(\d+)/;
			} else {
				$day = $r->previous_sibling->previous_sibling->at('.day-b')->text =~ /(\d+)/;
			}

			next unless( defined $day && defined $url && defined $title && defined $hour);#obligatory
			$shows{$url} = {title=> $title, dates=>[], desc=>$desc, img=>$img} if not $shows{$url};
			push @{ $shows{$url}->{dates} }, $year.'-'.$month."-$day $hour";
		}
		return \%shows;
	},
	'opera' => sub {
		my$self=shift; my%shows;
		my$dom = Mojo::DOM->new($self->html);

		for my$r ($dom->find('.row-performance')->each) {#tylko tu sie rozni
			my$desc	= '';#unobligatory
			my$img 	= $r->at('.item-photo')->img->attr('src');
			my$url 	= $r->at('.item-title')->a->attr('href');
			my$title = $r->at('.item-title')->a->text;
			my$hour 	= $r->at('.item-time > .vcentered')->text;
			my($day) = $r->at('.item-date > .vcentered')->text =~ /(\d+)/;

			next unless( defined $day && defined $url && defined $title && defined $hour);#obligatory
			$shows{$url} = {title=> $title, dates=>[], desc=>$desc, img=>$img} if not $shows{$url};
			push @{ $shows{$url}->{dates} }, $year.'-'.$month."-$day $hour";
		}
		return \%shows;
	}
);
sub parse {
	my$self = shift;
	my($what) = $self->what =~ /(^[^_]+)/;

	my%shows = %{ $parsers{$what}($self) };
	$shows{what} = $self->what;

#	$self->shows( \%shows );
	return \%shows;
}
sub view {
	print 'view'

	}

sub BUILD {
   my$self = shift;
   mkdir $self->cache if !-e $self->cache;   #TODO cwd first!
}

sub load {
	my$self = shift;
}
__PACKAGE__->meta->make_immutable;
1;
