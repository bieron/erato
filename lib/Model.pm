package Model;
use Moose;
use Data::Dumper;
use utf8;
use DBI;
use DBD::Pg;
use constant DESC_LEN => 600;
my$dbh = DBI->connect('dbi:Pg:dbname=erato', '', '');

has 'where' => (is => 'rw', isa => 'ArrayRef', default=> sub {[]});
has 'command' => (is=>'rw', isa=>'Str');
has 'from' => (is=>'rw', isa=>'Str');
has 'link' => (is=>'rw', isa=>'Str', default => 'AND');

our%places = (
	'slowacki_duza' 		=> 'Słowacki - Duża Scena',
	'slowacki_mala' 		=> 'Słowacki - Scena Kameralna',
	'stary_duza'	 		=> 'Stary - Duża Scena',
	'stary_mala'	 		=> 'Stary - Scena Miniatura',
	'filharmonia'	 		=> 'Filharmonia',
	'bagatela-karmelicka'=> 'Bagatela - Karmelicka',
	'bagatela-sarego'		=> 'Bagatela - Sarego',
	'opera'					=> 'Opera'
);

sub to_str {
	my$el = shift;
	if(ref $el eq 'ARRAY') {
		$el = ' IN('.join(',',@$el).')';
	} else {
		$el = "=$el"
	}
}

sub place {
	my$self = shift;
	my$p = shift;
	if (ref $p eq 'ARRAY') {
   	$p = join ',', map { "'$places{$_}'" } @$p;
		$p = 'IN('.$p.')';
	} else {
		$p = "='$places{$p}'"
	}
	push @{$self->where}, 'place '.$p;
	$self
}
sub dow {
	my$self = shift;
	my$days = to_str( shift );
	push @{ $self->where },  'EXTRACT(dow FROM showtime) '.$days;
	$self
}

sub get_shows {
	my$self = shift;
	my$keep = shift;
	my$s = 'SELECT url,showtime,title,place,img,description FROM shows NATURAL JOIN dates';
	my$w = '';
	if( $self->where ) {
		my$l = $self->link;
		$w .= ' WHERE '. join(" $l ", @{$self->where});
	}
	$self->where( [] ) unless $keep;
	$s .= $w .' ORDER BY showtime';
  # warn $s;
	my$res = $dbh->selectall_arrayref($s);#, ['showtime']);
}

sub save_shows {
	my$self = shift;
	my$what = shift;
	my@shows = @{ shift() };

	my%inserted;
	my$r = '';
	for my$s (@shows) {
		my%s = %$s;
		goto SHOWTIME if $inserted{$s{url}};
		$inserted{$s{url}}++;

		if (defined $s{desc}) {
			utf8::encode( $s{desc} );                   #chyba nie dziala
			$s{desc} = substr $s{desc}, 0, DESC_LEN;
		}
		utf8::encode( $s{title} );

		$dbh->do('INSERT INTO shows VALUES (?,?,?,?,?)', undef,
					$s{url},
					$s{title},
					$places{ $what },
					$s{img},
					$s{desc}
		);#will set off a lot of warnings due to unique constraint, hence goto

		SHOWTIME:
		$r .= "$s{url}\t\t$s{date}\n";
		$dbh->do('INSERT INTO dates VALUES (?,?)',undef,
					$s{url},
					$s{date});
	}
	#print $r;
	return;
}
__PACKAGE__->meta->make_immutable;
1;

=encoding utf8

=head1 NAME
Model

=head1 NAME
moduł erato komunikujący się z bazą

=head2 METHODS

=over 12

=item C<to_str>
formatuje argument do postaci wymaganej przez klauzulę WHERE
do self->where dodaje "=$_" albo "IN($_->[0], ...)" jesli $_ jest arefem

=item C<place>
formatuje argument do postaci wymaganej przez klauzulę WHERE
podmienia klucz identyfikujący teatr z właściwym stringiem obecnym w bazie, np 'slowacki_duza' => 'Słowacki - Duża Scena'
do self->where dodaje "=$_" albo "IN($_->[0], ...)" jesli $_ jest arefem

=item C<dow>
do self->where dodaje warunek sprawdzajacy spektakle odbywaja sie w dniach podanych w $_ albo @$_ jako liczby 0..6 gdzie 0 to niedziela
np $model->dow([1,2,3]) jesli interesuje nas pon, wt, sr

=item C<get_shows>
wrzuca dane z self->where do zapytania sql i zwraca wynik w postaci array_ref
czysci self->shows jesli jako argument dostaje true

=item C<save_shows>
oczekuje danych w postaci stringa z kluczem nazwy teatru (np slowacki_duza) oraz listy hrefow z kluczami:
keys = (url, date, title, img, desc)
argumenty sa pozycyjne
zapisuje do bazy danych (tabele shows i dates) przedstawienia i ich daty
wrzuca tylko pierwsze wystapienie przedstawienia (dla ograniczenia warningow - i tak jest unique constraint)

=back

=head1 AUTHOR
dj-jb@o2.pl

=cut
