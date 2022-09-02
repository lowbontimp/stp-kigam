#!/usr/bin/env perl

use strict ;
use warnings ;

#https://earthquake.usgs.gov/fdsnws/event/1/query?maxmag=10.000000&minmag=6.000000&lat=30.000000&format=text&minradius=30.000000&maxradius=90.000000&maxdepth=600.000000&mindepth=100.000000&end=2020-01-01T00:00:00&nodata=404&start=2019-01-01T00:00:00&lon=120.000000
my %urls ;
$urls{usgs} = "https://earthquake.usgs.gov/fdsnws/event/1/query" ;
$urls{gcmt} = "https://service.iris.edu/fdsnws/event/1/query" ;
$urls{isc} = "http://www.isc.ac.uk/fdsnws/event/1/query" ;

my $url = $urls{usgs} ;

my $start = "2012-01-01T00:00:00" ;
my $end = "2013-01-01T00:00:00" ;
my $minmag = 5.000000 ;
my $maxmag = 10.000000 ;
my $lat = 45.030102 ; 
my $lon = -127.155998 ;
my $minradius = 30.000000 ; #deg
my $maxradius = 90.000000 ;
my $mindepth = 100.000000 ; #km
my $maxdepth = 600.000000 ;

my $nodata = 404 ;
my $format = "text" ;

my $fullurl = "$url?maxmag=$maxmag&minmag=$minmag&lat=$lat&format=$format&minradius=$minradius&maxradius=$maxradius&maxdepth=$maxdepth&mindepth=$mindepth&end=$end&nodata=$nodata&start=$start&lon=$lon" ;

`wget \'$fullurl\' -O events01.txt` ;

#us70006p18|2019-12-20T11:39:52.874|36.5374|70.4555|212|us|us|us|us70006p18|mww|6.1|us|49 km SW of Jurm, Afghanistan
#0          1                       2       3       4   5  6  7  8          9   10  11 12

#print "skip on\n" ;
open(my $fh,"<events01.txt") ;
my $n = 0 ;
while(my $l=<$fh>){
	chomp($l) ;
	if ($l=~m{^\#}){
		next ;
	}
	$n++ ;
	$n = sprintf("%04d",$n) ;
	my @c = split(/\|/,$l) ;
	my ($y,$m,$d,$H,$M,$S) = split("[-T:]",$c[1]) ;
	print "!# $l\n" ;
	print "dir data01/$n\n" ;
	print "dirresp resp01/$n\n" ;
	print "evt $y/$m/$d,$H:$M:$S $c[2] $c[3] $c[4] $c[10]($c[9]) O(-200) O(1800) 7D % -- BHZ\n" ;
	print "evt $y/$m/$d,$H:$M:$S $c[2] $c[3] $c[4] $c[10]($c[9]) O(-200) O(1800) 7D % -- HHZ\n" ;
}
close($fh) ;
