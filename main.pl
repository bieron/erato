#!/usr/bin/perl -w

local $\ = "\n";
local $, = ', ';

use strict;
use lib 'lib';
use utf8;
binmode STDOUT, ':utf8';
use open ':std', ':encoding(UTF-8)';
use Show;
use Crawler;

my($m,$y) = (localtime)[4,5];
if( ($m+=2) == 13) {
   $m = 1, $y += 1;
}
$y += 1900;

my$url = 'www.filharmonia.krakow.pl/Repertuar/Kalendarium/?events=process&date=month&'
   .'month='.$m.'&year='.$y;
my$parser = sub {
   my$self = shift;
   my$html = $self->html;
   my@parsed = ();
   my$row = '';
   while( $html =~ m@<tr> .*? h1 .*? 
   href="([^"]+)"> ([^<]+) </a> .*? </h1>    #url, title
   (.*?) </td .*?                            #description
   dataday"> ([^<]+) .*?                     #date_dow
#   hour [^>]+ >(\d{1,2}.\d{2})               #hour
   hour [^>]+ >(.*?)</td>               #hour
   .*?</tr>@gx) {
      my($url, $title, $desc, $date, $hour) = ($1,$2,$3,$4,$5);
      $url = 'http://www.filharmonia.krakow.pl/' . $url;
      my@hours = $hour =~ /(\d{1,2}.\d{2})/;
      $hour = join ', ', @hours;
      my$dow;
      ($date,$dow) = split /\s*,\s*/, $date;
      push @parsed, {url=>$url, title=>$title, desc=>$desc, date=>$date, dow=>$dow, hour=>$hour};
   }
   @parsed;
};
my$c = new Crawler(address => $url, parser => $parser);
#my$c = new Crawler(address => $url, row => '.*?');
$c->fetch;
$c->crawl;
#print $c->html;
