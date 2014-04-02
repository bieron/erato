package Model;
use Moose;
use Data::Dumper;
#use Rose::DB;
#our@ISA = qw/Rose::DB/;
#__PACKAGE__->use_private_registry;
#__PACKAGE__->register_db(
#	driver   => 'pg',
#	database => 'erato',
#	host     => 'localhost',
#	username => '',
#	password => '',
#);
use DBI;
use DBD::Pg;
my$dbh = DBI->connect('dbi:Pg:dbname=erato', '', '');

#has 'data' => (is => 'rw', isa => 'HashRef', default => sub {{}});
has 'where' => (is => 'rw', isa => 'ArrayRef', default=> sub {[]});
has 'command' => (is=>'rw', isa=>'Str');
has 'from' => (is=>'rw', isa=>'Str');
has 'link' => (is=>'rw', isa=>'Str', default => 'AND');

my%places = (
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
		$p = "='$p'"
	}
	my@where = @{ $self->where };
	push @where,  'place '.$p;
	$self->where(\@where);
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
	my$s = 'SELECT url,showtime FROM shows NATURAL JOIN dates';
	my$w = '';
	if( $self->where ) {
		my$l = $self->link;
		$w .= ' WHERE '. join(" $l ", @{$self->where});
	}
	$s .= $w .' ORDER BY showtime';
	print $s;
	my$res = $dbh->selectall_hashref($s, ['showtime']);
	print Dumper($res);
}


sub save {
	my$self = shift;
	print @_;
	my%ss = %{ shift() };
	my$what = $ss{what};
	delete $ss{what};

   for my$url (keys %ss) {
		utf8::encode( $ss{$url}->{desc} );                   #chyba nie dziala
		utf8::encode( $ss{$url}->{title} );
		$ss{$url}->{desc} = substr($ss{$url}->{desc}, 0, 600);

		$dbh->do('INSERT INTO shows VALUES (?,?,?,?,?)', undef,
					$url, $ss{$url}->{title},
					$places{ $what },
					$ss{$url}->{img},
					$ss{$url}->{desc}
		);
		for my$date (@{$ss{$url}->{dates}}) {
			$dbh->do('INSERT INTO dates VALUES (?,?)',undef,
						$url, $date);
		}
	}
}
sub load {
	my$self = shift;
}
