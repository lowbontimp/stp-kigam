#!/usr/bin/env perl

use strict ;
use warnings ;

#43.76 125.31

#https://earthquake.usgs.gov/fdsnws/event/1/query?maxmag=10.000000&minmag=6.000000&lat=30.000000&format=text&minradius=30.000000&maxradius=90.000000&maxdepth=600.000000&mindepth=100.000000&end=2020-01-01T00:00:00&nodata=404&start=2019-01-01T00:00:00&lon=120.000000
my %urls ;
$urls{usgs} = "https://earthquake.usgs.gov/fdsnws/event/1/query" ;
$urls{gcmt} = "https://service.iris.edu/fdsnws/event/1/query" ;
$urls{isc} = "http://www.isc.ac.uk/fdsnws/event/1/query" ;

my $url = $urls{isc} ;

&getevents("2007-01-01","2008-12-31","events.xml") ;

sub getevents {
	my ($start,$end,$output)=@_ ;
	#my $start = "2012-01-01T00:00:00" ;
	#my $end = "2013-01-01T00:00:00" ;
	my $minmag = 5.5 ;
	my $maxmag = 10.0 ;
	my $lat = 43.76 ; 
	my $lon = 125.31 ;
	my $minradius = 5.000000 ; #deg
	my $maxradius = 120.000000 ;
	my $mindepth = 0.0 ; #km
	my $maxdepth = 1000.0 ;
	
	my $nodata = 404 ;
	#my $format = "text" ;
	my $format = "xml" ;
	
	my $fullurl = "$url?maxmag=$maxmag&minmag=$minmag&lat=$lat&format=$format&minradius=$minradius&maxradius=$maxradius&maxdepth=$maxdepth&mindepth=$mindepth&end=$end&nodata=$nodata&start=$start&lon=$lon" ;
	
	#`wget \'$fullurl\' -O events01.txt` ;
	`wget \'$fullurl\' -O $output` ;
	
	#us70006p18|2019-12-20T11:39:52.874|36.5374|70.4555|212|us|us|us|us70006p18|mww|6.1|us|49 km SW of Jurm, Afghanistan
	#0          1                       2       3       4   5  6  7  8          9   10  11 12
}
	
