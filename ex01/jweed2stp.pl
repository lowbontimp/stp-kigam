#!/usr/bin/env perl

use strict ;
use warnings ;

print "dirresp resp01\n" ;
#print "skip on\n" ;
open(my $fh,"<cascadia1234.events") ;
my $n = 0 ;
while(my $l=<$fh>){
	chomp($l) ;
	$n++ ;
	$n = sprintf("%04d",$n) ;
	my @c = split(",",$l) ;
	my ($y,$m,$d,$H,$M,$S) = split("[- :]",$c[1]) ;
	print "dir data01/$n\n" ;
	print "evt $y/$m/$d,$H:$M:$S $c[2] $c[3] $c[4] $c[8]($c[7]) O(-200) O(1800) 7D % -- BHZ\n" ;
	print "evt $y/$m/$d,$H:$M:$S $c[2] $c[3] $c[4] $c[8]($c[7]) O(-200) O(1800) 7D % -- HHZ\n" ;
}
close($fh) ;
