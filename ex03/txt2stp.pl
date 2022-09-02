#!/usr/bin/env perl

use strict ;
use warnings ;

print "skip on\n" ;

&txt2stp("IU","events.txt","netspec01.txt") ;

sub txt2stp{
	my ($net,$evttxtfname,$netspec)=@_ ;
	#my $evttxtfname = "events.YP.txt" ;
	open(my $fh,"<$evttxtfname") ;
	#12079939 2009-01-03T20:18:37.66Z 0.0684 132.1845 0 4.70(mb) 4.90(mb1) 4.20(mb1mx) 4.70(mbtmp) 6.30(MS) 6.30(Ms1) 5.50(ms1mx)
	#13404580 2009-01-03T20:23:19.78Z 36.4414 70.7733 204.2282 5.80(mb)
	#0        1                       2       3       4        5
	my $n = 0 ;
	while(my $l=<$fh>){
		chomp($l) ;
		if ($l=~m{^\#}){
			next ;
		}
		$n++ ;
		$n = sprintf("%04d",$n) ;
		my @c = split(/ /,$l) ;
		my $lat = $c[2] ;
		my $lon = $c[3] ;
		my $dep = $c[4] ;
		my $mag = $c[5] ;
		my ($y,$m,$d,$H,$M,$S) = split("[-T:Z]",$c[1]) ;
		print "!# $l\n" ;
		print "dir data01/$net.$n\n" ;
		print "dirresp resp01/$net.$n\n" ;
		my @opts = &netspec($net,$netspec) ;
		foreach my $opt (@opts){
			print "evt $y/$m/$d,$H:$M:$S $lat $lon $dep $mag O(-200) O(1800) $opt\n" ;
		}
	}
	close($fh) ;
}

sub netspec {
	my ($net,$fname)=@_ ;
	my @output ;
#AA % 2009-01-01 2011-12-31 -- BH_
#BB % 1998-01-01 1999-12-31 01 HH_
#0  1 2          3          4  5
	open(my $f,"<$fname") ;
	while(my $l=<$f>){
		chomp($l) ;
		if ($l=~m{^\#}){
			next ;
		}
		my @c = split(" ",$l) ;
		if ($c[0] eq $net){
			push(@output,"$net $c[1] $c[4] $c[5]") ;
		}
	}
	close($f) ;
	return @output ;
}
