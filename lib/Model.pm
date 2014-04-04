package Model;
use Moose;
use Data::Dumper;
use utf8;
use DBI;
use DBD::Pg;
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

sub toStr {
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
#	my@where = @{ $self->where };

#	push @where,  'place '.$p;
#	$self->where(\@where);
	$self
}
sub dow {
	my$self = shift;
	my$place = toStr( shift );
	my@where = @{ $self->where };
	push @where,  'EXTRACT(dow FROM showtime) '.$place;
	$self->where(\@where);
	$self
}

sub getShows {
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

sub save {
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
			$s{desc} = substr($s{desc}, 0, 600);
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
}
__PACKAGE__->meta->make_immutable;
