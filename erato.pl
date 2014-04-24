#!/usr/bin/perl -w
use strict;

local $\ = "\n";
local $, = ', ';

use lib 'lib';
use utf8;
binmode STDOUT, ':utf8';
use open ':std', ':encoding(UTF-8)';
use Model;
use Crawler;
use Sender;
use Data::Dumper;

my$c = new Crawler;
my$m = new Model;
my$s = new Sender;

sub fetchAll {
	for my$w (qw/slowacki_duza slowacki_mala filharmonia stary_duza stary_mala opera bagatela-sarego bagatela-karmelicka/) {
		my$aref = $c->fetch(what => $w);
		$m->save_shows($w, $aref);
	}
}

sub mailRegular {
	my$aref = $m->place('filharmonia')->dow(5)->month()->get_shows;			#filharmonia w piatki
	$s->add($aref);
	$aref = $m->place([qw/bagatela-sarego bagatela-karmelicka/])->dow([2,4,6])->month()->get_shows;			#bagatela w srodki piatki niedziele
	$s->add($aref);
	$aref = $m->place('stary_duza')->dow([2,4,6])->month()->get_shows;		#stary duza w srodki piatki niedziele
	$s->add($aref);
	$aref = $m->place('stary_mala')->dow([1,3,5])->month()->get_shows;		#stary kameralna w wtorki czwartki soboty
	$s->add($aref);
	$aref = $m->place([qw/slowacki_duza slowacki_mala opera/])->month()->get_shows;	#reszta we wszystkie dni
	$s->add($aref);
	$s->write_mail(qw/bagatela-karmelicka bagatela-sarego stary_duza stary_mala slowacki_duza slowacki_mala opera filharmonia/);
#	return;
	$s->recipients( ['jbieron@gmail.com'] );
	$s->send_mail;
}


fetchAll();
mailRegular();

=encoding utf8

=head1 NAME
erato

=head1 DESCRIPTION
parser i prosty newsletter repertuarów teatrów, opery i filharmonii

=head1 AUTHOR
dj-jb@o2.pl

=cut
