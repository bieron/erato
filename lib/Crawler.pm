package Crawler;
use Mouse;
use Encode;
use LWP;
use Mojo::UserAgent;
use Data::Dump 'dump';
use Mojo::DOM;
use utf8;
#use open qw/:std :utf8/;

my@date = (localtime)[5,4];
our$year = $date[0] + 1900;
our$month = ($date[1]+2)%13;

has 'html'  => (is => 'rw', isa => 'Str');
has 'cache' => (is => 'ro', isa => 'Str', default => 'cache');
has 'what'  => (is => 'rw', isa =>'Str');

my$ua = Mojo::UserAgent->new;#->max_redirects(3);
$ua->transactor->name('Mozilla/8.0');

sub recent {#class function
    time - shift() < 3600;#okres waznosci 1h
}
sub fetch {
    my$self = shift;
    $self->get_html(@_);
    return $self->parse_html;
}

my@monthNames = qw/styczen luty marzec kwiecien maj czerwiec lipiec sierpien wrzesien pazdziernik listopad grudzien/;

my%url_of = (
    'stary_duza'          => 'http://www.stary.pl/pl/repertuar/1',
    'stary_mala'          => 'http://www.stary.pl/pl/repertuar/2',
    'slowacki_duza'       => 'http://slowacki.krakow.pl/pl/repertuar/duza_scena/_get/month/!m/year/!y',
    'slowacki_mala'       => 'http://slowacki.krakow.pl/pl/repertuar/scena_miniatura/_get/month/!m/year/!y',
    'filharmonia'         => 'http://www.filharmonia.krakow.pl/Repertuar/Kalendarium/?events=process&date=month&month=!m&year=!y',
    'bagatela-sarego'     => 'http://www.bagatela.pl/Repertuar/?repertoire=repertoire&view_date=!y-!m',
    'bagatela-karmelicka' => 'http://www.bagatela.pl/Repertuar/?repertoire=repertoire&view_date=!y-!m'
);

sub get_html {
    my($self,%a) = @_;

    $self->what($a{what});
    $a{month} ||= $month;
    $a{year}  ||= $year;

    my($place) = $self->what =~ /([^-]+)/;
    my$fn = "cache/$year-$month-$place.html";

    goto NOCACHE;
    open my$f, '<', $fn or goto NOCACHE;
    my$mt = (stat $f)[10];
    (close $f and goto NOCACHE) if not recent $mt;
    { local $/; $self->html( <$f> ) }
    close $f;
    return 304;#http non modified

    NOCACHE:
    my$rsvp;

    if ($a{what} =~ /stary/) {
        $rsvp = $ua->post( $url_of{ $a{what} }, form => {
            dateFrom    => "$year-$month-01",
            dateTo      => "$year-$month-31",
            idSpectacle => '',
            show        => 'Pokaż',
        } );
    } elsif ($a{what} eq 'opera') {
        $rsvp = $ua->get( 'http://opera.krakow.pl/pl/repertuar/na-afiszu/' . $monthNames[ $month-1 ] );
    } else {
        my$url = $url_of{ $self->what };
        $url =~ s/!m/$month/;
        $url =~ s/!y/$year/;
        $rsvp = $ua->get( $url );
    }
    $rsvp = $rsvp->res;
    my$code = $rsvp->code;
    if($code < 200 || $code  > 299) {
        open my$f, '>', "cache/$year-$month-$code.html" or warn q/can't write/;
        print $f $rsvp->body; close $f;
        warn 'got '.$code;
    }
    my$html = $rsvp->body;
    my($body) = $html =~ m/(<body.*body>)/s;
    $body =~ s/<script.*?script>//sg;
    $body =~ s/<br\s*\/?>/\n/g;#for text fields
    $body =~ s/\s*\n\s*/\n/g;
    $body =~ s/\n\n+/\n/g;
    $body =~ s/[\t ]+/ /g;
    my($title) = ($html =~ m/<title.*?>([^<]+)<\/title>/);
    $html = decode('utf8', '<html><head><title>'.$title.' at '.time.'</title></head>'.$body.'</html>');

    open $f, '>', $fn or warn "can't write to file $fn";
    print $f $html;
    close $f;

    $self->html($html);
    return $code;
}

my%parser = (
    slowacki => {marker => '#tableCalendary tr', 'sub' => sub {
            my($r) = @_;
            my($img,$desc) = (' ',' ');#unobligatory
            my($day)       = $r =~ />\s*           ([0123]?\d)        \s*</x;
            return unless defined $day;

            my($url)    = $r =~ /href="         ([^"]+)               "/x;
            my($title)  = $r =~ /<a[^>]+>\s*    (.*?)           \s*<\/a/x;
            my($hour)   = $r =~ />\s*           (\d{1,2}:\d\d)     \s*</x;

            my$date = "$year-$month-$day $hour";
            return unless( defined $date && defined $url && defined $title);#obligatory
            return {url=>$url, title=> $title, date=>$date, desc=>$desc, img=>$img};
        }
    },
    stary => {marker => '.mainFrameNews', 'sub' => sub {
            my($r) = @_;
            my($img)    = $r =~ /src="\.?([^"]+)/;
            my$desc     = $r->find('.mainFrameNewsDesc');#->all_text;
            my$title    = $desc->at('a')->text;
            $title      = "$title";
            $desc       = $desc->all_text;
            $desc       = "$desc"; #Mojo::Collection stringify method overload
            my($hour)   = $r =~ /(\d\d:\d\d)/;
            my($url)    = $r =~ /href="     (.+?spektakl[^"]+)  /x;
            my($date)   = $r->previous_sibling->previous_sibling =~ /([\d-]{8,10})/;
            $date .= " $hour";

            return unless( defined $date && defined $url && defined $title);#obligatory
            return {url=>$url, title=> $title, date=>$date, desc=>$desc, img=>$img};
        }
    },
    filharmonia => {marker => '.event', 'sub' => sub {
            my($r) = @_;
            my($img)     = $r->at('.thunbail') =~ /src="\.?([^"]+)/;
            my$title        = $r->at('h1')->a->text;
            return if (!defined $title || $title =~ /DZIECI/);#to mnie nie interesuje
            my$desc         = $r->find('p')->all_text(0);
            $desc           = "$desc";
            $desc =~ s/\n+/<br\/>/g;

            my$hour         = $r->at('.hour')->text;
            my($url)    = $r =~ /href="      ([^"]+)      /x;
            my($date)   = $r =~ /dataday">\s* ([\d-]+)  /x;

            $date .= " $hour";
            return unless( defined $date && defined $url && defined $title);#obligatory
            return {url=>$url, title=> $title, date=>$date, desc=>$desc, img=>$img};
        }
    },
    'bagatela-karmelicka' => {marker => '.not-empty-a', 'sub' => sub {
            my($r) = @_;
            my($img,$desc)=(' ',' ');#unobligatory
            my$url      = $r->at('.name-a')->a->attr('href');
            my$title    = $r->at('.name-a')->a->text;
            my@hour         = split "\n", $r->find('.hour-a')->all_text;

            my$day = $r->at('.day-a');
            if ($day) {
                ($day)  = $day->text =~ /(\d+)/;
            } else {
                ($day) = $r->previous_sibling->previous_sibling->at('.day-a')->text =~ /(\d+)/;
            }
            my@date = map{ s/ /:/g; "$year-$month-$day $_" } @hour;
            return unless( @date && defined $url && defined $title);#obligatory

            my@ret = {url=>$url, title=> $title, date=>$date[0], desc=>$desc, img=>$img};
            push @ret, {%{$ret[0]}, date => $date[1]} if @hour == 2;
            @ret;
        }
    },
    'bagatela-sarego' => {marker => '.not-empty-b', 'sub' => sub {
            my($r) = @_;
            my($img,$desc)=('','');#unobligatory
            my$url      = $r->at('.name-b')->a->attr('href');
            my$title    = $r->at('.name-b')->a->text;
            my@hour     = split "\n", $r->find('.hour-b')->all_text;

            my$day = $r->at('.day-b');
            if ($day) {
                ($day)  = $day->text =~ /(\d+)/;
            } else {
                ($day) = $r->previous_sibling->previous_sibling->at('.day-b')->text =~ /(\d+)/;
            }
            my@date = map{ s/ /:/g; "$year-$month-$day $_" } @hour;
            return unless( @date && defined $url && defined $title);#obligatory

            my@ret = {url=>$url, title=> $title, date=>$date[0], desc=>$desc, img=>$img};
            push @ret, {%{$ret[0]}, date => $date[1]} if @hour == 2;
            @ret;
        }
    },
    opera => {marker => '.row-performance', 'sub'=> sub {
            my($r) = @_;
            my$desc  = '';#unobligatory
            my$img   = $r->at('.item-photo')->img->attr('src');
            my$url   = $r->find('.item-title a')->attr('href')->[0];

            my$title = $r->find('.item-title a')->text->[0];
            my$hour  = $r->at('.item-time > .vcentered')->text;
            my($day) = $r->at('.item-date > .vcentered')->text =~ /(\d+)/;

            my$date = "$year-$month-$day $hour";
            return unless( defined $date && defined $url && defined $title);#obligatory
            return {url=>$url, title=> $title, date=>$date, desc=>$desc, img=>$img};
        }}
);
sub parse_html {
    my($self) = @_;
    my($what) = $self->what =~ /(^[^_]+)/;
    my$dom = Mojo::DOM->new($self->html);

    my@shows;# = map { $parser{$what}->{sub}{$_} } @{ $dom->find($parser{$what}->{marker})->each() };
    for ($dom->find($parser{$what}->{marker})->each) {
        my@show = $parser{$what}->{sub}($_);
        push @shows, @show;# if $show;
    }
    return \@shows;
}
sub BUILD {
    my($self) = @_;
    mkdir $self->cache if !-e $self->cache;   #TODO cwd first!
}

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head1 NAME
Crawler


=head1 DESCRIPTION
moduł erato ściągający, parsujący i archiwizujący

=head2 METHODS

=over 12

=item C<recent>
sprawdza czy ma aktualny repertuar

=item C<fetch>
opakowanie dla get_html i parse_html

=item C<get_html>
usiluje sciagnac (lub przeczytac z archiwum) aktualny repertuar podany w $_{what}

=item C<parse_html>
korzystajac z instrukcji w %parser, wyszukuje interesujące dane i zwraca je w postaci listy referencji do hashy

=back

=head1 AUTHOR
dj-jb@o2.pl

=cut
