#!/usr/bin/perl -w
use strict;

local $\ = "\n";
local $, = ', ';

use lib 'lib';
use utf8;
binmode STDOUT, ':utf8';
use open ':std', ':encoding(UTF-8)';
#use Show;
use Crawler;


my$c = new Crawler;
#$c->fetch(what => 'slowacki_duza');
#$c->fetch(what => 'bagatela-karmelicka');
#$c->fetch(what => 'slowacki_mala');
#$c->fetch(what => 'filharmonia');
#$c->fetch(what => 'stary_duza');
#$c->fetch(what => 'opera');
#$c->view(format => 'html');

for my$w (qw/slowacki_duza slowacki_mala filharmonia stary_duza stary_mala opera bagatela-sarego bagatela-karmelicka/) {
	$c->fetch(what => $w);
}
