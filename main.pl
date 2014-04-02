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
		my$href = $c->fetch(what => $w);
		$m->save($href);
	}
}

sub mailRegular {
	my$aref = $m->place('filharmonia')->dow(5)->getShows;			#filharmonia w piatki
	$s->add($aref);
	$aref = $m->place(['bagatela-sarego','bagatela-karmelicka'])->dow([2,4,6])->getShows;			#bagatela w srodki piatki niedziele
	$s->add($aref);
	$aref = $m->place('stary_duza')->dow([2,4,6])->getShows;		#stary duza w srodki piatki niedziele
	$s->add($aref);
	$aref = $m->place('stary_mala')->dow([1,3,5])->getShows;		#stary kameralna w wtorki czwartki soboty
	$s->add($aref);
	$aref = $m->place(['slowacki_duza', 'slowacki_mala', 'opera'])->getShows;	#reszta we wszystkie dni
	$s->add($aref);
	$s->write;
	$s->recipients( ['jbieron@gmail.com', 'dj-jb@o2.pl', 'jbieron@student.agh.edu.pl', 'jasiu@lazy.if.uj.edu.pl'] );
	$s->send;
}
mailRegular();
#$c->fetch(what => 'slowacki_duza');
#$c->fetch(what => 'bagatela-karmelicka');
#$c->fetch(what => 'slowacki_mala');
#$c->fetch(what => 'filharmonia');
#$c->fetch(what => 'stary_duza');
#$c->fetch(what => 'opera');
#$c->view(format => 'html');
#$m->place(['stary_duza', 'opera'])->dow(5)->getShows;
#die;
