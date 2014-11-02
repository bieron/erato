package Sender;
use Mouse;
use Data::Dumper;
use utf8;
#binmode(STDOUT, ':utf8');
use open qw/:std :utf8/;
use Time::Local;

has 'mails'      => (is=> 'rw', isa=> 'HashRef', default=> sub {{}});
has 'title'      => (is=> 'rw', isa=> 'Str', default => 'Kurier Kulturalny');
has 'message'    => (is=> 'rw', isa=> 'Str', default => 'Kurier Kulturalny');
has 'shows'      => (is=> 'rw', isa=> 'ArrayRef', default=> sub {[]});
has 'recipients' => (is=> 'rw', isa=> 'ArrayRef');

my$year = $Crawler::year;
my$month = $Crawler::month;
my$fn = "$year-$month-mail.html";
#my$fn = "mail.html";

sub add {
    my ($self, $show) = @_;
    $self->shows( [ @{$self->shows}, @{ $show } ] );
}
sub send_mail {
    my ($self) = @_;
    my$mails = join ',',@{$self->recipients};
    print STDERR "sending to $mails";
    open EM, '>', $fn;
    local$\="\n";
    print EM $self->message;
    close EM;
    system("lib/apollo.sh $fn $mails");
    return;
}
=begin
    for my$mail (@{$self->recipients}) {
        print STDERR "sending to $mail";
#open EM, '| /usr/bin/sendmail -t';
        open EM, '>', $fn;
        local$\="\n";
#       print EM "To: $mail";
#       print EM 'From: jb@guru.ltd';
#       print EM 'Subject: '.$self->title."\n";
#       print EM 'Patrz załącznik';
#       print EM 'Content-type: text/html';
        print EM $self->message;
        close EM;
        print $cmd;
        `$cmd`;
        print $cmd;
        `$cmd`;
    }
=cut
sub thead { return '<tr><th colspan="3">'.$_[0].'</th></tr>'}

my %base = (
    'Opera'       => 'http://opera.krakow.pl',
    'Filharmonia' => 'http://filharmonia.krakow.pl',
    'Słowacki'    => 'http://slowacki.krakow.pl',
    'Bagatela'    => 'http://bagatela.pl',
    'Stary'       => 'http://stary.pl'
);
sub abs_path {
    my($place, $url) = @_;
    if ($url =~ m@^/@) {
        $place =~ s/ .+//;
        $url = $base{$place} . $url;
    }
    $url;
}

my@dow = qw/pon wt śr czw pt sob nd/;
sub format_times {
    my@a = @{$_[0]};
    my$times = join('<br/>', map {
        my($y,$m,$d) = split /-/, $_;
        ($d) = $d =~ m/(\d+)/;
        my$time = timegm(0,0,0,$d, $m-1, $y-1900);
        my$dw = $dow[ (localtime $time)[6]-1 ];
        s/.+-(\d\d) (\d\d:\d\d).+/$1 $dw $2/;
        $_;
        } @a);
    $times;
}
sub trow {
    my$bg = ('#fff', '#ddf')[ shift ];
    my$place = shift;
    my$times = format_times( shift );
#   my$times =  join('<br/>', map { substr($_, 8, -3) } @{shift()});
    my($url,$title,$img,$desc) = @_;
    $url = abs_path($place,$url);
    if($img) {
        $img = abs_path($place,$img);
        $img = "<a href='$url'><img src='$img'/>";
    } else {$img = ''}
    if($desc) {
        $desc = "<br/>$desc";
    } else {$desc = ''}

    return "<tr style='background:$bg'>
    <td width='100px'>$img</td>
    <td style='padding:5px;width:500px'><a href='$url'>$title</a>$desc</td>
    <td style='text-align:center;padding:10px'>$times</td>
    </tr>";
}
sub write_mail {
    my ($self, @seq) =@_;
    @seq = map {$Model::places{$_} } @seq;
    my($header, $footer) = do{local$/="\n\n"; <DATA>};
    $header =~ s/!title/$self->title()/e;
    my$str = $header;

    my%s;
    for my$r (@{$self->shows}) {
        my($url,$time,$title,$place,$img,$desc) = @$r;
        $s{$place} = {} unless $s{$place};
        $s{$place}->{$url} = [[],$url,$title,$img,$desc] unless $s{$place}->{$url};
        push @{ $s{$place}->{$url}->[0] }, $time;
    }

    @seq = sort keys %s unless @seq;
    my$odd = 1;
    for my $s (@seq) {
        $str .= '<table style="margin:15px auto">';
        $str .= thead($s);
        my@shows = sort {$a->[0][0] gt $b->[0][0] } values %{$s{$s}};
        for my$show (@shows) {
            $str .= trow($odd, $s, @$show);
            $odd = !$odd;
        }
        $str .= '</table>';
    }
    open my$f, '>', $fn;
    print $f $str;
    close $f;
    $self->message($str);
}
__PACKAGE__->meta->make_immutable;

=head1 NAME
Sender

=head1 DESCRIPTION
moduł erato wysylajacy newsletter

=head2 METHODS

=over 12

=item C<add>
dodaje do $self->shows hrefy przedstawien podane jako arg

=item C<send_mail>
wysyla $self->message o tytule $self->title do $self->recipients jako BCC

=item C<thead>
zwraca string z naglowkiem tablicy teatru

=item C<abs_path>
2 pozycyjne arg: $place i $url
jesli arg zaczyna sie od /, prefixuje go baseurlem dla strony $place

=item C<format_times>
zwraca dla defaultowego sql'owego datetime 'DD DOW HH:MM'

=item C<trow>
wywolywany z write mail
przyjmuje trzy argumenty:
$odd - true or false, decyduje o naprzemiennym tle <tr>
$place - string nazwy placowki, np 'Słowacki - Duża Scena'
@show - ([terminy], url, tytul, img[src], opis) - img i opis nie sa obowiazkowe
zwraca string - pojedynczy <tr> ze spektaklem

=item C<write_mail>
tworzy html string i zapisuje go do pliku $fn oraz $self->message
wywoluje thead i trow

=back

=head1 AUTHOR
dj-jb@o2.pl

=cut

__DATA__
<html><head>
<meta http-equiv="content-type" content="text/html; charset=utf-8" />
<title>!title</title>
</head><body>

</body></html>
