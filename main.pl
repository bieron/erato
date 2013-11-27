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



my$s = new Show(title => 'seks nocy letniej', director => 'klata');
my$c = new Crawler(address => 'ismycomputeron.com');
print $c->fetch;
print $c->html;
