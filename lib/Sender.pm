package Sender;
use Moose;
use Data::Dumper;
use utf8;
use open qw/:std :utf8/;

has 'mails' 		=> (is=> 'rw', isa=> 'HashRef', default=> sub {{}});
has 'title' 		=> (is=> 'rw', isa=> 'Str', default => 'Kurier Kulturalny');
has 'message' 		=> (is=> 'rw', isa=> 'Str', default => 'Kurier Kulturalny');
has 'shows' 		=> (is=> 'rw', isa=> 'ArrayRef', default=> sub {[]});
has 'recipients' 	=> (is=> 'rw', isa=> 'ArrayRef');

my@date = (localtime)[5,4];
my$year = $date[0] + 1900;
my$month = ($date[1]+2)%13;
my$fn = "cache/$year-$month-mail.html";

sub add {
	my$self=shift;
	$self->shows( [ @{$self->shows}, @{shift()} ] );
}
sub send {
	my$self=shift;
	for my$mail (@{$self->recipients}) {
		print STDERR "sending to $mail";
		open EM, '| /usr/bin/sendmail -t';
		local$\="\n";
		print EM "To: $mail";
		print EM 'From: jb@guru.ltd';
		print EM $self->title."\n";
		print EM 'Content-type: text/html';
		print EM $self->message;
		close EM;
	}

}
sub thead { return '<tr><th colspan="3">'.shift.'</th></tr>'}
sub abs_path {
	my($place, $url) = @_;
	if ($url =~ m@^/@) {
		$place =~ s/ .+//;
		my%base = (
			Opera => 'http://opera.krakow.pl',
			Filharmonia => 'http://filharmonia.krakow.pl',
			'Słowacki' => 'http://slowacki.krakow.pl',
			Bagatela => 'http://bagatela.pl',
			Stary => 'http://stary.pl'
		);
		$url = $base{$place} . $url;
	}
	$url;
}
sub trow {
	my$bg = ('#fff', '#ddf')[ shift ];
	my$place = shift;
	my$times =  join('<br/>', map { substr($_, 8, -3) } @{shift()});
	my($url,$title,$img,$desc) = @_;
	$url = abs_path($place,$url);
   if($img) {
		$img = abs_path($place,$img);
		$img = "<a href='$url'><img width='100%' src='$img'/>";
	} else {$img = ''}
   if($desc) {
		$desc = "<br/>$desc";
	} else {$desc = ''}

	return "<tr style='background:$bg'><td width='170px'>$img</td><td style='padding:5px;width:500px'><a href='$url'>$title</a>$desc</td><td style='text-align:center;padding:5px'>$times</td></tr>";
}
sub write {
	my$self=shift;
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
	my$odd = 1;
	for my$p (sort keys %s) {
		$str .= '<table style="margin:15px 0">';
		$str .= thead($p);
		my@shows = sort {$a->[0][0] lt $b->[0][0] } values %{$s{$p}};
		for my$show (@shows) {
			$str .= trow($odd, $p, @$show);
			$odd = !$odd;
		}
		$str .= '</table>';
	}
	open my$f, '>', $fn;
	print $f $str;
	close $f;
	$self->message($str);
}
1;
__DATA__
<html><head>
<meta http-equiv="content-type" content="text/html; charset=utf-8" />
<title>!title</title>
</head><body>

</body></html>
