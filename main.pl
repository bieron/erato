#!/usr/bin/perl -w

local $\ = "\n";
local $, = ', ';

=begin
mkdir 'sache' if !-e 'sache';
open my$f, '>', 'sache/test' or die 'wtf';

print 'yep';
exit;
=cut

use strict;
use lib 'lib';
use Show;
use Crawler;

my($m,$y) = (localtime)[4,5];
if( ($m+=2) == 13) {
   $m = 1, $y += 1;
}
$y += 1900;

my$s = new Show(title => 'seks nocy letniej', director => 'klata');


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
   hour [^>]+ >(\d{1,2}.\d{2})               #hour
   .*?</tr>@gx) {
      my($url, $title, $desc, $date, $hour) = ($1,$2,$3,$4,$5);
      my$dow;
      ($date,$dow) = split /\s*,\s*/, $date;
      $title = ucfirst lc $title;#TODO move this feature to Show attribute trigger or builder
      $desc =~ s@<br[^>]+>@\n@g;#TODO move this feature to Show attribute trigger or builder
      $desc =~ s/&nbsp;//g;
      $desc =~ s/&ndash;/-/g;
      $desc =~ s/<[^>]+>//g;
      push @parsed, {url=>$url, title=>$title, desc=>$desc, date=>$date, dow=>$dow, hour=>$hour};
   }
   @parsed;
};
my$c = new Crawler(address => $url, parser => $parser);
#my$c = new Crawler(address => $url, row => '.*?');
print $c->fetch;
$c->crawl;
#print $c->html;
